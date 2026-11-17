let
  # The command that records what a system runs, for node_exporter.
  recordSystemVersion =
    {
      config,
      lib,
      pkgs,
      self,
    }:
    let
      script = pkgs.writeShellApplication {
        name = "system-version";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./system-version.sh;
      };
    in
    "${lib.getExe script} ${config.monitoring.textfileDirectory}/system-version.prom ${
      self.inputs.nixpkgs.rev or "unknown"
    } ${toString self.inputs.nixpkgs.lastModified}";
in
{
  description = "Serves node metrics to the monitoring server and, on NixOS, ships the journal to it";

  interface =
    { lib, ... }:
    {
      options = {
        alwaysOn = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this machine is meant to be online at all times. Only
            always-on machines alert: when they stop answering, and on failed
            units, filling disks and hardware errors. Turn it off for laptops
            and handhelds, which then only show up on dashboards.
          '';
        };

        extraCollectors = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            node_exporter collectors to enable besides the ones this service
            enables for the machine's system. See the node_exporter README for
            the collector list.
          '';
          example = [
            "conntrack"
            "processes"
          ];
        };

        exporters = lib.mkOption {
          type = lib.types.attrsOf lib.types.port;
          default = { };
          description = ''
            The machine's Prometheus exporters besides node_exporter, by job
            name, at the port each listens on. The server scrapes them over the
            tailnet; the machine's modules read the ports from
            `monitoring.exporters`.
          '';
          example = {
            kea-dhcp4 = 9547;
          };
        };

        smart.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Export the drives' SMART health (NixOS); off for a virtual machine, whose disks have none.";
        };

        extraLabels = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Labels added to every metric the server scrapes from this agent and to every journal line it ships.";
          example = {
            role = "router";
          };
        };

        rules = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [ ];
          description = ''
            Prometheus alerting and recording rules about this machine's own
            metrics, which the server evaluates as one group named after the
            machine. Every alert needs `labels.severity`: `critical` notifies
            at any hour, `warning` outside the server's quiet hours.
          '';
          example = [
            {
              alert = "DhcpDown";
              expr = ''node_systemd_unit_state{instance="router", name="kea-dhcp4-server.service", state="active"} == 0'';
              for = "3m";
              labels.severity = "critical";
              annotations.summary = "DHCP is down";
            }
          ];
        };

        dashboards = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          default = { };
          description = ''
            Grafana dashboard models about this machine, by name. The server
            provisions them next to its own; names must be unique across agents.
          '';
        };
      };
    };

  perInstance =
    { settings, roles, ... }:
    {
      nixosModule =
        {
          config,
          lib,
          pkgs,
          self,
          ...
        }:
        let
          inherit (config.monitoring) textfileDirectory;
          lokiAuth = config.clan.core.vars.generators.loki-auth;
          # nixos-facter's finding: "none" on hardware, the hypervisor in a VM.
          virtualisation = config.hardware.facter.report.virtualisation or "none";

          # The journal goes to the main server: a backup keeps no logs.
          mainServers = lib.filter (server: !server.settings.backup) (lib.attrValues roles.server.machines);
          serverSettings =
            if lib.length mainServers != 1 then
              throw "@adeci/monitoring: requires exactly one server that is not a backup, got ${toString (lib.length mainServers)}"
            else
              (lib.head mainServers).settings;

          acmeCertificates = pkgs.writeText "acme-certificates" (
            lib.concatLines (
              lib.mapAttrsToList (
                name: certificate: "${name}\t${certificate.directory}/cert.pem"
              ) config.security.acme.certs
            )
          );

          acmeCertificateExpiry = pkgs.writeShellApplication {
            name = "acme-certificate-expiry";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.openssl
            ];
            text = builtins.readFile ./acme-certificate-expiry.sh;
          };

          filesystemDisks = pkgs.writeShellApplication {
            name = "filesystem-disks";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.util-linux
            ];
            text = builtins.readFile ./filesystem-disks.sh;
          };

          bootTiming = pkgs.writeShellApplication {
            name = "boot-timing";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.jq
              config.systemd.package
            ];
            text = builtins.readFile ./boot-timing.sh;
          };
        in
        {
          monitoring.exporters = settings.exporters;

          assertions = [
            {
              assertion = settings.smart.enable -> virtualisation == "none";
              message = "@adeci/monitoring: ${config.clan.core.settings.machine.name} runs in ${virtualisation}, whose disks have no SMART data; set smart.enable = false in its agent settings.";
            }
          ];

          services.prometheus.exporters.smartctl.enable = settings.smart.enable;

          services.prometheus.exporters.node = {
            enable = true;
            enabledCollectors = [
              "cpu"
              "cpufreq"
              "meminfo"
              "filesystem"
              "diskstats"
              "netdev"
              "netclass"
              "loadavg"
              "stat"
              "uname"
              "systemd"
              "pressure"
              "hwmon"
              "edac"
              "textfile"
            ]
            ++ settings.extraCollectors;
            extraFlags = [
              "--collector.disable-defaults"
              "--collector.textfile.directory=${textfileDirectory}"
            ];
          };

          systemd.tmpfiles.rules = [ "d ${textfileDirectory} 0755 root root -" ];

          # The server scrapes over the tailnet.
          networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
            config.services.prometheus.exporters.node.port
          ]
          ++ lib.optional settings.smart.enable config.services.prometheus.exporters.smartctl.port
          ++ lib.attrValues settings.exporters;

          services.vector = {
            enable = true;
            journaldAccess = true;
            # Offline, stopping would wait on the server; what isn't sent stays in the disk buffer.
            gracefulShutdownLimitSecs = 5;
            settings = {
              data_dir = "/var/lib/vector";

              # The credentials systemd hands the service, by name; the vars end them with a newline.
              secret.credentials = {
                type = "directory";
                path = "/run/credentials/vector.service";
                remove_trailing_whitespace = true;
              };

              sources.journal.type = "journald";

              # Queries match levels by syslog name; kernel lines have no unit, so they go by their program.
              transforms.labelled = {
                type = "remap";
                inputs = [ "journal" ];
                source = ''
                  .level = get(["emerg", "alert", "crit", "err", "warning", "notice", "info", "debug"], [to_int(.PRIORITY) ?? 6]) ?? "info"
                  .service_name = ._SYSTEMD_UNIT || .SYSLOG_IDENTIFIER
                '';
              };

              sinks.loki = {
                type = "loki";
                inputs = [ "labelled" ];
                endpoint = "http://${serverSettings.host}/loki";
                encoding.codec = "text";
                labels = settings.extraLabels // {
                  job = "systemd-journal";
                  instance = config.clan.core.settings.machine.name;
                  service_name = "{{ service_name }}";
                  transport = "{{ _TRANSPORT }}";
                  level = "{{ level }}";
                };
                auth = {
                  strategy = "basic";
                  user = lokiAuth.files.username.value;
                  password = "SECRET[credentials.loki-auth-password]";
                };
                # While the server is out of reach the journal waits here, then in the journal itself.
                buffer = {
                  type = "disk";
                  max_size = 512 * 1024 * 1024;
                  when_full = "block";
                };
                healthcheck.enabled = false;
              };
            };
          };

          systemd.services.vector = {
            # Stops before tailscaled at shutdown, while it can still reach the server.
            after = [ "tailscaled.service" ];
            serviceConfig.LoadCredential = [ "loki-auth-password:${lokiAuth.files.password.path}" ];
          };

          systemd.services.acme-certificate-expiry = lib.mkIf (config.security.acme.certs != { }) {
            description = "Export ACME certificate expiry times for node_exporter";
            startAt = "*:0/15";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe acmeCertificateExpiry} ${acmeCertificates} ${textfileDirectory}/acme-certificates.prom";
            };
          };

          # The fleet dashboard's per-disk panels group filesystems by the disk under them.
          systemd.services.filesystem-disks = {
            description = "Map mounted filesystems to their physical disks for node_exporter";
            wantedBy = [ "multi-user.target" ];
            after = [ "local-fs.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${lib.getExe filesystemDisks} ${textfileDirectory}/filesystem-disks.prom";
            };
          };

          # Once a boot: how long it took, and the shutdown before it. A simple service's start is done at once,
          # so the boot can finish while the script waits for it to.
          systemd.services.boot-timing = {
            description = "Export this boot's and the last shutdown's timing for node_exporter";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart = "${lib.getExe bootTiming} ${textfileDirectory}/boot-timing.prom";
            };
          };

          # On every boot and switch; given the activated system, it also tells whether its kernel waits for a reboot.
          system.activationScripts.system-version.text = "${
            recordSystemVersion {
              inherit
                config
                lib
                pkgs
                self
                ;
            }
          } $systemConfig";
        };

      darwinModule =
        {
          config,
          lib,
          pkgs,
          self,
          ...
        }:
        let
          inherit (config.monitoring) textfileDirectory;
          machineName = config.clan.core.settings.machine.name;
          tailnetAddress = self.inventory.machines.${machineName}.tailnet;
          nodeExporter = lib.getExe config.services.prometheus.exporters.node.package;
          socketfilterfw = "/usr/libexec/ApplicationFirewall/socketfilterfw";

          macosHealth = pkgs.writeShellApplication {
            name = "macos-health";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.jq
              pkgs.macmon
              pkgs.smartmontools
            ];
            text = builtins.readFile ./macos-health.sh;
          };
        in
        {
          assertions = [
            {
              assertion = tailnetAddress != null;
              message = "@adeci/monitoring: the Mac ${machineName} needs its tailnet address, machines.${machineName}.tailnet in inventory/network.nix, for node_exporter to listen on.";
            }
          ];

          services.prometheus.exporters.node = {
            enable = true;
            # The application firewall allows a program on every network, so it listens on the tailnet only.
            listenAddress = lib.mkIf (tailnetAddress != null) tailnetAddress;
            enabledCollectors = [
              "cpu"
              "meminfo"
              "filesystem"
              "diskstats"
              "netdev"
              "loadavg"
              "uname"
              "boottime"
              "time"
              "textfile"
            ]
            ++ settings.extraCollectors;
            extraFlags = [
              "--collector.disable-defaults"
              # The rest are the sealed system volume at /, macOS's helper volumes and the secrets ramdisk.
              "--collector.filesystem.mount-points-include=^/(System/Volumes/Data|nix)$"
              "--collector.textfile.directory=${textfileDirectory}"
            ];
          };

          # Before launchd starts the exporter: the application firewall only lets in listeners allowed before they started.
          system.activationScripts.preActivation.text = ''
            ${socketfilterfw} --add ${nodeExporter} > /dev/null
            ${socketfilterfw} --unblockapp ${nodeExporter} > /dev/null
            mkdir -p ${textfileDirectory}
          '';

          # What node_exporter cannot read on a Mac: the internal SSD's SMART data, which needs root, the memory pressure level, the CPU temperature and the battery's health.
          launchd.daemons.macos-health = {
            command = "${lib.getExe macosHealth} ${textfileDirectory}/macos-health.prom";
            serviceConfig = {
              RunAtLoad = true;
              # The page's temperature is as old as the last run.
              StartInterval = 60;
              StandardErrorPath = "/var/log/macos-health.log";
            };
          };

          # On every deploy: a Mac changes what it runs only then, and the file outlasts reboots.
          system.activationScripts.postActivation.text = recordSystemVersion {
            inherit
              config
              lib
              pkgs
              self
              ;
          };
        };
    };
}

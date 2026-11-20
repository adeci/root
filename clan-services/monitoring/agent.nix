let
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

  recordTailscaleKeyExpiry =
    {
      config,
      lib,
      pkgs,
    }:
    let
      script = pkgs.writeShellApplication {
        name = "tailscale-key-expiry";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          config.services.tailscale.package
        ];
        text = builtins.readFile ./tailscale-key-expiry.sh;
      };
    in
    "${lib.getExe script} ${config.monitoring.textfileDirectory}/tailscale-key-expiry.prom";
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
            Whether this machine should be online at all times. Only always-on
            machines alert when down, and on failed units, filling disks and
            hardware errors. Turn it off for laptops and handhelds, which then
            alert only on their backups.
          '';
        };

        extraCollectors = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            node_exporter collectors to enable on top of this service's
            defaults. See the node_exporter README for the list.
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
            The machine's other Prometheus exporters, by job name and port. The
            server scrapes them over the tailnet; modules read the ports from
            `monitoring.exporters`.
          '';
          example = {
            kea-dhcp4 = 9547;
          };
        };

        probes = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  description = "The address to request.";
                };
                instance = lib.mkOption {
                  type = lib.types.str;
                  description = "Machine serving the name. The probe's metrics carry it as `instance`, so the alert is held back while that machine is down.";
                };
                redirect = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Count a redirect as up, without following it.";
                };
              };
            }
          );
          default = { };
          description = ''
            HTTP checks this machine runs for the servers (NixOS), by public
            name. A name is up while its address answers 2xx. Runs
            blackbox_exporter, one request per server scrape.
          '';
          example = {
            "example.com" = {
              url = "https://example.com/health";
              instance = "web";
            };
          };
        };

        smart.enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Export the drives' SMART health (NixOS). Off for VMs, whose disks have none.";
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
            Prometheus alerting and recording rules on this machine's own
            metrics, evaluated by the server as one group named after the
            machine. Every alert needs `labels.severity`: `critical` notifies at
            any hour, `warning` outside the server's quiet hours.
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
            Grafana dashboard models for this machine, by name. The server
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
          yaml = pkgs.formats.yaml { };
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

          resticSnapshots = pkgs.writeShellApplication {
            name = "restic-snapshots";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.jq
            ];
            text = builtins.readFile ./restic-snapshots.sh;
          };

          # One "<backup>\t<path>" line per entry in each backup's `paths` or `exclude`.
          backupPaths =
            option:
            pkgs.writeText "restic-${option}" (
              lib.concatLines (
                lib.concatLists (
                  lib.mapAttrsToList (
                    backup: job: map (path: "${backup}\t${path}") job.${option}
                  ) config.services.restic.backups
                )
              )
            );

          # A prober without an IPv6 route would fail every name with an IPv6 address.
          httpProbe.preferred_ip_protocol = "ip4";
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

          services.prometheus.exporters.blackbox = lib.mkIf (settings.probes != { }) {
            enable = true;
            configFile = yaml.generate "blackbox.yml" {
              modules = {
                http_2xx = {
                  prober = "http";
                  http = httpProbe;
                };
                http_redirect = {
                  prober = "http";
                  http = httpProbe // {
                    follow_redirects = false;
                    valid_status_codes = [
                      301
                      302
                      303
                      307
                      308
                    ];
                  };
                };
              };
            };
          };

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

          services.vector = {
            enable = true;
            journaldAccess = true;
            # Don't hold up shutdown on the server; unsent lines stay in the disk buffer.
            gracefulShutdownLimitSecs = 5;
            settings = {
              data_dir = "/var/lib/vector";

              # The vars end with a newline.
              secret.credentials = {
                type = "directory";
                path = "/run/credentials/vector.service";
                remove_trailing_whitespace = true;
              };

              sources.journal.type = "journald";

              # Syslog level names; kernel lines have no unit, so use the program.
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
                # Holds lines while the server is unreachable; past that, the journal does.
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
            # Stop before tailscaled, while the server is still reachable.
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

          systemd.services.restic-snapshots = lib.mkIf (config.services.restic.backups != { }) {
            description = "Export each backup's snapshots, size and folders for node_exporter";
            startAt = "hourly";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe resticSnapshots} ${textfileDirectory} ${backupPaths "paths"} ${backupPaths "exclude"} ${lib.escapeShellArgs (lib.attrNames config.services.restic.backups)}";
              # Caches each repository's size and the snapshots it was counted for.
              StateDirectory = "restic-snapshots";
            };
          };

          systemd.services.tailscale-key-expiry = {
            description = "Export when the Tailscale key expires for node_exporter";
            startAt = "hourly";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = recordTailscaleKeyExpiry { inherit config lib pkgs; };
            };
          };

          # For the fleet dashboard's per-disk panels.
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

          # simple, not oneshot: the boot can finish while the script waits for it.
          systemd.services.boot-timing = {
            description = "Export this boot's and the last shutdown's timing for node_exporter";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart = "${lib.getExe bootTiming} ${textfileDirectory}/boot-timing.prom";
            };
          };

          # Every boot and switch; $systemConfig lets it flag a pending reboot.
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
              message = "@adeci/monitoring: ${machineName} needs machines.${machineName}.tailnet in inventory/network.nix for node_exporter to listen on.";
            }
          ];

          services.prometheus.exporters.node = {
            enable = true;
            # The app firewall allows a program on every network: listen on the tailnet only.
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
              # Skips the sealed system volume, macOS helper volumes and the secrets ramdisk.
              "--collector.filesystem.mount-points-include=^/(System/Volumes/Data|nix)$"
              "--collector.textfile.directory=${textfileDirectory}"
            ];
          };

          # Before launchd starts it: the firewall only admits listeners allowed beforehand.
          system.activationScripts.preActivation.text = ''
            ${socketfilterfw} --add ${nodeExporter} > /dev/null
            ${socketfilterfw} --unblockapp ${nodeExporter} > /dev/null
            mkdir -p ${textfileDirectory}
          '';

          # What node_exporter can't get on macOS; SMART needs root.
          launchd.daemons.macos-health = {
            command = "${lib.getExe macosHealth} ${textfileDirectory}/macos-health.prom";
            serviceConfig = {
              RunAtLoad = true;
              # Dashboard temperatures are only as fresh as the last run.
              StartInterval = 60;
              StandardErrorPath = "/var/log/macos-health.log";
            };
          };

          launchd.daemons.tailscale-key-expiry = {
            command = recordTailscaleKeyExpiry { inherit config lib pkgs; };
            serviceConfig = {
              RunAtLoad = true;
              StartInterval = 3600;
              StandardErrorPath = "/var/log/tailscale-key-expiry.log";
            };
          };

          # Deploys only: a Mac's system changes only then, and the file survives reboots.
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

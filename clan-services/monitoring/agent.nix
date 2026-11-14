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

        useSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use HTTPS when pushing the journal to the monitoring server.";
        };

        extraLabels = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Labels added to every metric the server scrapes from this agent and to every journal line it ships.";
          example = {
            role = "router";
          };
        };

        journal.mode = lib.mkOption {
          type = lib.types.enum [
            "all"
            "nixos"
            "explicit"
          ];
          default = "all";
          description = ''
            Which journal entries to ship to Loki:
              - "all":      every journal entry (default)
              - "nixos":    services explicitly enabled through NixOS `services.*.enable`
              - "explicit": only the services listed in `journal.include`
          '';
        };

        journal.include = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Explicit service list when `journal.mode = \"explicit\"`. Omit the `.service` suffix.";
          example = [
            "nginx"
            "grafana"
          ];
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
          options,
          pkgs,
          ...
        }:
        let
          inherit (config.monitoring) textfileDirectory;
          lokiAuth = config.clan.core.vars.generators.loki-auth;

          serverMachineCount = builtins.length (builtins.attrNames roles.server.machines);
          serverSettings =
            if serverMachineCount != 1 then
              throw "@adeci/monitoring: requires exactly one server machine, got ${toString serverMachineCount}"
            else
              (lib.head (lib.attrValues roles.server.machines)).settings;

          # Services enabled by this configuration rather than by default.
          enabledServiceUnits = map (name: "${name}.service") (
            lib.attrNames (
              lib.filterAttrs (
                name: service:
                options.services.${name} ? enable
                && options.services.${name}.enable ? default
                && options.services.${name}.enable.default != service.enable
                && service.enable
              ) config.services
            )
          );

          # The units whose journal to ship; null ships every entry.
          journalUnits =
            if settings.journal.mode == "all" then
              null
            else if settings.journal.mode == "nixos" then
              enabledServiceUnits
            else
              map (service: "${service}.service") settings.journal.include;

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
        in
        {
          monitoring.exporters = settings.exporters;

          services.prometheus.exporters.node = {
            enable = true;
            enabledCollectors = [
              "cpu"
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

              sources.journal = {
                type = "journald";
              }
              // lib.optionalAttrs (journalUnits != null) { include_units = journalUnits; };

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
                endpoint = "${if settings.useSSL then "https" else "http"}://${serverSettings.host}/loki";
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
        };

      darwinModule =
        {
          config,
          lib,
          self,
          ...
        }:
        let
          machineName = config.clan.core.settings.machine.name;
          tailnetAddress = self.inventory.machines.${machineName}.tailnet;
          nodeExporter = lib.getExe config.services.prometheus.exporters.node.package;
          socketfilterfw = "/usr/libexec/ApplicationFirewall/socketfilterfw";
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
            ]
            ++ settings.extraCollectors;
            extraFlags = [
              "--collector.disable-defaults"
              # The rest are the sealed system volume at /, macOS's helper volumes and the secrets ramdisk.
              "--collector.filesystem.mount-points-include=^/(System/Volumes/Data|nix)$"
            ];
          };

          # Before launchd starts the exporter: the application firewall only lets in listeners allowed before they started.
          system.activationScripts.preActivation.text = ''
            ${socketfilterfw} --add ${nodeExporter} > /dev/null
            ${socketfilterfw} --unblockapp ${nodeExporter} > /dev/null
          '';
        };
    };
}

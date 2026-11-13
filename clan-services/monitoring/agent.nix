{
  description = "Ships system metrics and journal logs to the monitoring server via Alloy";

  interface =
    { lib, ... }:
    {
      options = {
        alwaysOn = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this machine is meant to be online at all times. Only
            always-on machines alert: when they stop reporting, and on failed
            units, filling disks and hardware errors. Turn it off for laptops
            and handhelds, which then only show up on dashboards.
          '';
        };

        extraCollectors = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Additional `prometheus.exporter.unix` collectors to enable beyond the
            defaults. See the Alloy docs for the collector list.
          '';
          example = [
            "conntrack"
            "processes"
          ];
        };

        useSSL = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Use HTTPS when connecting to the monitoring server.";
        };

        scrapeInterval = lib.mkOption {
          type = lib.types.str;
          default = "15s";
          description = "How often Alloy scrapes its local exporters.";
        };

        extraLabels = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Additional external labels applied to every metric and log line from this agent.";
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

        journal.relabelRules = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra Alloy `rule` blocks appended to the `loki.relabel \"journal\"` component.";
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

          journalUnits =
            if settings.journal.mode == "all" then
              null
            else if settings.journal.mode == "nixos" then
              enabledServiceUnits
            else
              map (service: "${service}.service") settings.journal.include;

          alloyConfig = builtins.toFile "config.alloy" (
            import ./alloy.nix {
              inherit lib textfileDirectory journalUnits;
              inherit (settings) scrapeInterval extraCollectors extraLabels;
              inherit (config.monitoring) scrapeTargets;
              machineName = config.clan.core.settings.machine.name;
              serverUrl = "${if settings.useSSL then "https" else "http"}://${serverSettings.host}";
              journalRelabelRules = settings.journal.relabelRules;
            }
          );

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
          services.alloy = {
            enable = true;
            extraFlags = [
              "--server.http.enable-pprof=false"
              "--disable-reporting=true"
            ];
          };

          # Through /etc/alloy, the default configPath, a new config reloads Alloy rather than restarting it.
          environment.etc."alloy/config.alloy".source = alloyConfig;

          systemd.services.alloy.serviceConfig = {
            LoadCredential = [
              "prometheus-auth-password:${config.clan.core.vars.generators.prometheus-auth.files.password.path}"
              "loki-auth-password:${config.clan.core.vars.generators.loki-auth.files.password.path}"
            ];
            StateDirectory = [
              "alloy"
              "alloy/textfile"
            ];
          };

          systemd.services.acme-certificate-expiry = lib.mkIf (config.security.acme.certs != { }) {
            description = "Export ACME certificate expiry times for the metrics agent";
            startAt = "*:0/15";
            serviceConfig = {
              Type = "oneshot";
              ExecStart = "${lib.getExe acmeCertificateExpiry} ${acmeCertificates} ${textfileDirectory}/acme-certificates.prom";
            };
          };
        };
    };
}

_:
let
  defaultCollectors = [
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
    "textfile"
  ];
in
{
  _class = "clan.service";

  manifest = {
    name = "@adeci/monitoring";
    description = "Prometheus + Loki + Grafana observability stack with Alloy agents";
    categories = [ "Utility" ];
    readme = builtins.readFile ./README.md;
  };

  roles.agent = {
    description = "Ships system metrics and journal logs to the monitoring server via Alloy";

    interface =
      { lib, ... }:
      {
        options = {
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

          extraScrapeTargets = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  job = lib.mkOption {
                    type = lib.types.str;
                    description = "Prometheus `job` label for this scrape.";
                  };
                  target = lib.mkOption {
                    type = lib.types.str;
                    example = "127.0.0.1:9547";
                    description = "`address:port` to scrape.";
                  };
                };
              }
            );
            default = [ ];
            description = ''
              Extra Prometheus scrape jobs to forward to the monitoring server.
              Each entry becomes a `prometheus.scrape` Alloy component on this
              agent. The `instance` label is set to the machine's hostname.
            '';
            example = [
              {
                job = "kea-dhcp4";
                target = "127.0.0.1:9547";
              }
            ];
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
        };
      };

    perInstance =
      {
        settings,
        roles,
        ...
      }:
      {
        nixosModule =
          {
            config,
            lib,
            options,
            ...
          }:
          let
            inherit (lib)
              concatStringsSep
              escapeRegex
              optionalString
              ;

            machineName = config.clan.core.settings.machine.name;

            serverMachineCount = builtins.length (builtins.attrNames roles.server.machines);
            serverSettings =
              if serverMachineCount != 1 then
                throw "@adeci/monitoring: requires exactly one server machine, got ${toString serverMachineCount}"
              else
                (lib.head (lib.attrValues roles.server.machines)).settings;

            serverHost = serverSettings.host;
            protocol = "http" + optionalString settings.useSSL "s";
            serverURL = "${protocol}://${serverHost}";

            allCollectors = defaultCollectors ++ settings.extraCollectors;
            collectorsHCL = "[" + concatStringsSep ", " (map (c: "\"${c}\"") allCollectors) + "]";

            # Services whose `enable` was flipped on by a NixOS module.
            enabledNixosSystemdServices = map (v: "${v}.service") (
              lib.attrNames (
                lib.filterAttrs (_: v: v) (
                  lib.mapAttrs (
                    n: v:
                    builtins.hasAttr "enable" options.services.${n}
                    && builtins.hasAttr "default" options.services.${n}.enable
                    && options.services.${n}.enable.default != v.enable
                    && v.enable
                  ) config.services
                )
              )
            );

            explicitServices = map (s: "${s}.service") settings.journal.include;

            journalUnits =
              if settings.journal.mode == "all" then
                null
              else if settings.journal.mode == "nixos" then
                enabledNixosSystemdServices
              else
                explicitServices;

            journalUnitsRegex =
              if journalUnits == null || journalUnits == [ ] then
                null
              else
                "^(" + concatStringsSep "|" (map escapeRegex journalUnits) + ")$";

            journalKeepRule = optionalString (journalUnitsRegex != null) ''
              rule {
                action = "keep"
                source_labels = ["__journal__systemd_unit"]
                regex = ${builtins.toJSON journalUnitsRegex}
              }
            '';

            # Alloy component labels must match [a-zA-Z_][a-zA-Z0-9_]*; the
            # human-friendly job name (e.g. "kea-dhcp4") is preserved as the
            # Prometheus label, and the Alloy block name is sanitized.
            extraScrapeBlocks = concatStringsSep "\n" (
              map (
                s:
                let
                  alloyName = builtins.replaceStrings [ "-" ] [ "_" ] s.job;
                in
                ''
                  prometheus.scrape "${alloyName}" {
                    targets = [{
                      __address__ = "${s.target}",
                      instance    = "${machineName}",
                      job         = "${s.job}",
                    }]
                    honor_labels    = true
                    forward_to      = [prometheus.remote_write.server.receiver]
                    scrape_interval = "${settings.scrapeInterval}"
                  }
                ''
              ) settings.extraScrapeTargets
            );

            extraLabelPairs = lib.mapAttrsToList (n: v: "    \"${n}\" = \"${v}\",") settings.extraLabels;
            externalLabelsBlock =
              if settings.extraLabels == { } then
                ""
              else
                ''
                  external_labels = {
                  ${concatStringsSep "\n" extraLabelPairs}
                  }
                '';

            extraRelabelRules = concatStringsSep "\n" settings.journal.relabelRules;

            alloyConfig = builtins.toFile "config.alloy" ''
              // ───────── Metrics ─────────

              prometheus.exporter.unix "local_system" {
                set_collectors = ${collectorsHCL}

                textfile {
                  directory = "/var/lib/alloy/textfile"
                }
              }

              // Alloy's prometheus.exporter.unix auto-sets instance=<hostname>
              // on every node metric, matching the Prometheus convention.
              prometheus.scrape "node" {
                targets         = prometheus.exporter.unix.local_system.targets
                forward_to      = [prometheus.remote_write.server.receiver]
                scrape_interval = "${settings.scrapeInterval}"
              }

              // Alloy's own /metrics has no hostname context, so we force
              // instance=<hostname> via honor_labels + explicit target label.
              prometheus.scrape "alloy_self" {
                targets = [{
                  __address__ = "127.0.0.1:12345",
                  instance    = "${machineName}",
                  job         = "alloy",
                }]
                honor_labels    = true
                forward_to      = [prometheus.remote_write.server.receiver]
                scrape_interval = "${settings.scrapeInterval}"
              }

              ${extraScrapeBlocks}

              prometheus.remote_write "server" {
                ${externalLabelsBlock}
                endpoint {
                  url = "${serverURL}/prometheus/api/v1/write"
                  basic_auth {
                    username      = "alloy"
                    password_file = sys.env("CREDENTIALS_DIRECTORY") + "/prometheus-auth-password"
                  }
                }
              }

              // ───────── Logs ─────────

              loki.source.journal "systemd" {
                forward_to    = [loki.write.server.receiver]
                relabel_rules = loki.relabel.journal.rules
                labels        = {
                  job = "systemd-journal",
                }
              }

              loki.relabel "journal" {
                ${journalKeepRule}
                rule {
                  source_labels = ["__journal__hostname"]
                  target_label  = "instance"
                }
                rule {
                  source_labels = ["__journal__systemd_unit"]
                  target_label  = "service_name"
                }
                rule {
                  source_labels = ["__journal__transport"]
                  target_label  = "transport"
                }
                rule {
                  source_labels = ["__journal_priority_keyword"]
                  target_label  = "level"
                }
                ${extraRelabelRules}
                forward_to = []
              }

              loki.write "server" {
                ${externalLabelsBlock}
                endpoint {
                  url = "${serverURL}/loki/loki/api/v1/push"
                  basic_auth {
                    username      = "alloy"
                    password_file = sys.env("CREDENTIALS_DIRECTORY") + "/loki-auth-password"
                  }
                }
              }
            '';
          in
          {
            services.alloy = {
              enable = true;
              extraFlags = [
                "--server.http.enable-pprof=false"
                "--disable-reporting=true"
              ];
              configPath = alloyConfig;
            };

            environment.etc."alloy/config.alloy".source = config.services.alloy.configPath;

            systemd.services.alloy.serviceConfig = {
              ExecStart = lib.mkForce "${lib.getExe config.services.alloy.package} run /etc/alloy ${lib.escapeShellArgs config.services.alloy.extraFlags}";
              LoadCredential = [
                "prometheus-auth-password:${config.clan.core.vars.generators.prometheus-auth.files.password.path}"
                "loki-auth-password:${config.clan.core.vars.generators.loki-auth.files.password.path}"
              ];
              StateDirectory = [
                "alloy"
                "alloy/textfile"
              ];
            };
          };
      };
  };

  roles.server = {
    description = "Runs Prometheus, Loki, Grafana, and nginx — the central monitoring server";

    interface =
      { lib, ... }:
      {
        options = {
          host = lib.mkOption {
            type = lib.types.str;
            description = ''
              Fully qualified hostname every agent uses to reach this server. Must
              resolve to this machine from every agent — typically the Tailscale
              MagicDNS name. Also used as the Grafana `domain` and the nginx
              `server_name`.
            '';
            example = "sequoia.cymric-daggertooth.ts.net";
          };

          grafana.enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Grafana dashboards on this server.";
          };

          retentionDays = lib.mkOption {
            type = lib.types.int;
            default = 30;
            description = "Prometheus TSDB retention (days).";
          };

          loki.retentionHours = lib.mkOption {
            type = lib.types.int;
            default = 168;
            description = "Loki log retention (hours). 168h = 7 days.";
          };

          alertDelivery.ntfy = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Route critical Alertmanager notifications through alertmanager-ntfy.";
            };

            baseUrl = lib.mkOption {
              type = lib.types.str;
              default = "http://127.0.0.1:2586";
              description = "Local ntfy server base URL used by alertmanager-ntfy.";
            };

            topic = lib.mkOption {
              type = lib.types.str;
              default = "atlas-alerts";
              description = "ntfy topic for critical alert notifications.";
            };

            configGenerator = lib.mkOption {
              type = lib.types.str;
              default = "ntfy-alerts";
              description = "Clan vars generator that provides alertmanager-ntfy.yml.";
            };
          };
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            prometheusPort = 9090;
            alertmanagerPort = 9093;
            alertmanagerNtfyPort = 8000;
            lokiPort = 3100;
            lokiGrpcPort = 9095;
            grafanaPort = 3000;
            ntfyDelivery = settings.alertDelivery.ntfy;
            ntfyGenerator = config.clan.core.vars.generators.${ntfyDelivery.configGenerator} or null;
            ntfyBridgeConfig =
              if ntfyGenerator == null then
                throw "@adeci/monitoring: alertDelivery.ntfy requires clan vars generator '${ntfyDelivery.configGenerator}'"
              else
                ntfyGenerator.files."alertmanager-ntfy.yml".path;

            dashboards = import ./dashboards { inherit lib; };
            dashboardPath = pkgs.linkFarm "adeci-grafana-dashboards" (
              lib.mapAttrsToList (name: dashboard: {
                name = "${name}.json";
                path = pkgs.writeText "adeci-grafana-${name}.json" (builtins.toJSON dashboard);
              }) dashboards
            );

            alertRules = pkgs.writeText "adeci-monitoring-alerts.yml" ''
              groups:
                - name: fleet
                  rules:
                    - alert: HostStale
                      expr: |
                        (time() - max by (instance) (timestamp(node_uname_info))) > 180
                      for: 0m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Host {{ $labels.instance }} has not reported metrics for 3+ minutes"
                        description: "No samples received from {{ $labels.instance }} in the last 3 minutes. Agent down, network issue, or host offline."

                    - alert: DiskSpaceHigh
                      expr: |
                        100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}
                                 / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}) > 90
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} is over 90% full"

                    - alert: DiskSpaceCritical
                      expr: |
                        100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}
                                 / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}) > 95
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} is over 95% full"

                    - alert: InodeExhaustionHigh
                      expr: |
                        100 * (1 - node_filesystem_files_free{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}
                                 / node_filesystem_files{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}) > 90
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Filesystem {{ $labels.mountpoint }} on {{ $labels.instance }} is over 90% inode-full"

                    - alert: SystemdUnitFailed
                      expr: node_systemd_unit_state{state="failed"} == 1
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Systemd unit {{ $labels.name }} on {{ $labels.instance }} has been failed for 5+ minutes"

                - name: stack-health
                  rules:
                    - alert: AlloyWriteFailing
                      expr: |
                        sum by (instance) (rate(prometheus_remote_write_samples_failed_total[5m])) > 0
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Alloy agent on {{ $labels.instance }} is failing remote_write requests"

                    - alert: PrometheusIngestBroken
                      expr: |
                        rate(prometheus_tsdb_wal_corruptions_total[5m]) > 0
                        or
                        rate(prometheus_remote_storage_samples_failed_total[5m]) > 0
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Prometheus TSDB or remote-storage ingest is failing"

                    - alert: LokiIngestBroken
                      expr: |
                        sum(rate(loki_request_duration_seconds_count{route=~"api_prom_push|loki_api_v1_push",status_code=~"5.."}[5m])) > 0
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Loki push endpoint is returning 5xx errors"

                - name: router-health
                  rules:
                    - alert: JanusDown
                      expr: |
                        up{instance="janus",job="integrations/unix"} == 0
                      for: 3m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Janus unix exporter scrape is down"
                        description: "Alloy is still reporting, but Janus' node/unix scrape is failing. Check alloy.service and the local unix exporter on Janus. If Janus is fully offline, HostStale should also fire."

                    - alert: JanusSystemDegraded
                      expr: |
                        (max by(instance) (node_systemd_system_running{instance="janus"}) == 0)
                        or
                        (sum by(instance) (node_systemd_unit_state{instance="janus",state="failed"} == 1) > 0)
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus systemd is degraded or has failed units"
                        description: "Run systemctl --failed and systemctl is-system-running on Janus. Core router services have separate critical alerts; this catches other failed units before they become outages."

                    - alert: JanusCoreServiceDown
                      expr: |
                        node_systemd_unit_state{instance="janus",name=~"kea-dhcp4-server.service|unbound.service|nftables.service|tailscaled.service",state="active"} == 0
                      for: 3m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Janus core unit {{ $labels.name }} is inactive"
                        description: "A router data-plane or remote-access unit is not active. Check systemctl status {{ $labels.name }} on Janus."

                    - alert: JanusTelemetryUnitDown
                      expr: |
                        node_systemd_unit_state{instance="janus",name=~"alloy.service|prometheus-kea-exporter.service|prometheus-mikrotik-exporter.service|prometheus-mikrotik-poe-exporter.service|prometheus-unbound-exporter.service|prometheus-smokeping-exporter.service|janus-network-probe.timer|janus-routeros-health.timer|janus-firewall-counters.timer",state="active"} == 0
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus telemetry unit {{ $labels.name }} is inactive"
                        description: "A dashboard or alerting support unit is not active. Router forwarding may still work, but observability is degraded. Check systemctl status {{ $labels.name }} on Janus."

                    - alert: JanusExporterScrapeDown
                      expr: |
                        up{instance="janus",job=~"alloy|kea-dhcp4|mikrotik|mikrotik-poe|unbound|smokeping"} == 0
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus exporter scrape {{ $labels.job }} is down"
                        description: "Prometheus data for a Janus local exporter is unavailable. Check the matching systemd unit and local listener on Janus."

                    - alert: RouterOSDeviceDown
                      expr: |
                        janus_network_probe_up{instance="janus",group="routeros"} == 0
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "RouterOS device {{ $labels.target }} is unreachable"
                        description: "Janus cannot ping {{ $labels.target }} at {{ $labels.address }}. Check power, uplink, management VLAN, and the upstream switch path."

                    - alert: RouterOSApiScrapeDown
                      expr: |
                        mikrotik_scrape_collector_success{instance="janus",job="mikrotik"} == 0
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "RouterOS API scrape failed for {{ $labels.device }}"
                        description: "The Mikrotik exporter cannot collect API metrics for {{ $labels.device }}. Check the prometheus API user, RouterOS API service, and management VLAN reachability."

                    - alert: RouterOSHealthScrapeDown
                      expr: |
                        janus_routeros_health_scrape_success{instance="janus"} == 0
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "RouterOS health scrape failed for {{ $labels.name }}"
                        description: "Janus cannot read /system/health from this RouterOS device. Check the prometheus API user, RouterOS API service, and management VLAN reachability."

                    - alert: RouterOSHighTemperature
                      expr: |
                        max by(name) (janus_routeros_temperature_celsius{instance="janus"}) > 75
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "RouterOS device {{ $labels.name }} is hot"
                        description: "A RouterOS board, CPU, or PHY temperature is above 75C. Check rack airflow, PoE load, ambient temperature, and device placement."

                    - alert: RouterOSUplinkErrors
                      expr: |
                        (
                          sum by(name, interface) (
                            (
                              rate(mikrotik_interface_rx_error{instance="janus",job="mikrotik",name="nexus",interface=~"sfp-sfpplus1|sfp-sfpplus2|ether2|ether3"}[15m])
                              or rate(mikrotik_interface_rx_error{instance="janus",job="mikrotik",name="axon",interface="sfp-sfpplus1"}[15m])
                              or rate(mikrotik_interface_rx_error{instance="janus",job="mikrotik",name=~"zephyr|nimbus",interface="ether1"}[15m])
                            )
                            +
                            (
                              rate(mikrotik_interface_tx_error{instance="janus",job="mikrotik",name="nexus",interface=~"sfp-sfpplus1|sfp-sfpplus2|ether2|ether3"}[15m])
                              or rate(mikrotik_interface_tx_error{instance="janus",job="mikrotik",name="axon",interface="sfp-sfpplus1"}[15m])
                              or rate(mikrotik_interface_tx_error{instance="janus",job="mikrotik",name=~"zephyr|nimbus",interface="ether1"}[15m])
                            )
                          ) > 0.01
                        )
                        or
                        (
                          sum by(name, interface) (
                            increase(mikrotik_interface_link_downs{instance="janus",job="mikrotik",name="nexus",interface=~"sfp-sfpplus1|sfp-sfpplus2|ether2|ether3"}[15m])
                            or increase(mikrotik_interface_link_downs{instance="janus",job="mikrotik",name="axon",interface="sfp-sfpplus1"}[15m])
                            or increase(mikrotik_interface_link_downs{instance="janus",job="mikrotik",name=~"zephyr|nimbus",interface="ether1"}[15m])
                          ) > 0
                        )
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "RouterOS uplink {{ $labels.name }} {{ $labels.interface }} has errors"
                        description: "A switch/AP uplink has sustained RX/TX errors or link-down events. Check cable, SFP, PoE power, port negotiation, and the neighboring switch port."

                    - alert: JanusFirewallCountersStale
                      expr: |
                        (time() - max by(instance) (node_systemd_timer_last_trigger_seconds{instance="janus",name="janus-firewall-counters.timer"})) > 120
                      for: 2m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus firewall counters have not refreshed recently"
                        description: "The janus-firewall-counters.timer should run every 15 seconds. Check the timer and janus-firewall-counters.service; firewall policy may still work, but firewall dashboards are stale."

                    - alert: JanusInternetDown
                      expr: |
                        (max by(instance) (janus_network_probe_up{instance="janus",group="internet"}) == 0)
                        or
                        (min by(instance) (janus_network_probe_up{instance="janus",group="wan"}) == 0)
                        or
                        (max by(instance) (janus_dns_probe_up{instance="janus"}) == 0)
                      for: 3m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Janus WAN, internet, or DNS probe is down"
                        description: "The WAN gateway, all internet probes, or the local DNS probe has failed for multiple probe cycles. Check WAN link, ISP gateway, Unbound, and upstream DNS reachability."

                    - alert: JanusHighPacketLoss
                      expr: |
                        100 * (1 - (
                          sum by(instance) (rate(smokeping_response_duration_seconds_count{instance="janus",job="smokeping",group="internet"}[10m]))
                          /
                          clamp_min(sum by(instance) (rate(smokeping_requests_total{instance="janus",job="smokeping",group="internet"}[10m])), 0.001)
                        )) > 25
                      for: 10m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Janus internet packet loss is high"
                        description: "Smokeping has seen more than 25% loss to internet targets for 10+ minutes. Check WAN link quality, modem/ONT, ISP status, and upstream packet loss before changing firewall policy."

                    - alert: JanusHighLatency
                      expr: |
                        1000 * histogram_quantile(0.95, sum by(instance, le) (rate(smokeping_response_duration_seconds_bucket{instance="janus",job="smokeping",group="internet"}[10m]))) > 150
                      for: 15m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus internet p95 latency is high"
                        description: "Internet p95 ICMP latency has stayed above 150 ms. Check WAN congestion, bufferbloat, ISP path changes, and Router System resource panels."

                    - alert: JanusHighTemperature
                      expr: |
                        max by(instance, chip) (node_hwmon_temp_celsius{instance="janus",chip=~"platform_coretemp_0|nvme_nvme0"}) > 80
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus temperature is high on {{ $labels.chip }}"
                        description: "CPU or NVMe temperature is above 80C. Check airflow, dust, fan behavior, and sustained disk or CPU load before thermal throttling affects routing."

                    - alert: JanusRootDiskFull
                      expr: |
                        100 * (1 - node_filesystem_avail_bytes{instance="janus",mountpoint="/",fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"} / node_filesystem_size_bytes{instance="janus",mountpoint="/",fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}) > 95
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Janus root filesystem is almost full"
                        description: "Root filesystem usage is above 95%. Free space before services fail to write state, logs, or Nix profiles."

                    - alert: JanusConntrackPressure
                      expr: |
                        100 * node_nf_conntrack_entries{instance="janus"} / node_nf_conntrack_entries_limit{instance="janus"} > 80
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus conntrack table pressure is high"
                        description: "Conntrack usage is above 80% of the kernel limit. Look for connection floods, P2P bursts, stuck clients, or an undersized nf_conntrack_max."

                    - alert: JanusInterfaceFaults
                      expr: |
                        sum by(instance, device) (
                          rate(node_network_receive_errs_total{instance="janus",device=~"enp5s0|eno1|br-mgmt|vlan10|vlan20|vlan30"}[15m])
                          +
                          rate(node_network_transmit_errs_total{instance="janus",device=~"enp5s0|eno1|br-mgmt|vlan10|vlan20|vlan30"}[15m])
                        ) > 0.05
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Janus interface {{ $labels.device }} has sustained errors"
                        description: "A routed Janus interface is seeing sustained RX/TX errors. Firewall drops are intentionally excluded; check cable, switch port, SFP/NIC health, and link negotiation."
            '';
          in
          {
            # ── Firewall: only allow port 80 over Tailscale ──
            networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];

            # ── State folders (survive clan state restore) ──
            clan.core.state.monitoring.folders = [
              "/var/lib/${config.services.prometheus.stateDir}"
              config.services.loki.dataDir
            ]
            ++ lib.optionals ntfyDelivery.enable [
              "/var/lib/alertmanager"
            ];

            # ── PostgreSQL backend for Grafana ──
            clan.core.postgresql = lib.mkIf settings.grafana.enable {
              enable = true;
              users.grafana = { };
              databases.grafana = {
                create.options.OWNER = "grafana";
                restore.stopOnRestore = [ "grafana" ];
              };
            };

            # Grafana's NixOS module requires an explicit secret_key as of 26.05.
            # Generate one so dashboard/datasource secrets stay stable across rebuilds.
            clan.core.vars.generators = lib.optionalAttrs settings.grafana.enable {
              grafana-secret = {
                files.key = { };
                runtimeInputs = [ pkgs.openssl ];
                script = ''
                  openssl rand -hex 32 > "$out/key"
                '';
              };
            };

            # ── Prometheus ──
            services.prometheus = {
              enable = true;
              listenAddress = "127.0.0.1";
              port = prometheusPort;
              retentionTime = "${toString settings.retentionDays}d";
              extraFlags = [
                "--web.enable-remote-write-receiver"
              ];
              globalConfig = {
                scrape_interval = "30s";
                evaluation_interval = "30s";
              };
              alertmanagers = lib.optionals ntfyDelivery.enable [
                {
                  static_configs = [
                    { targets = [ "127.0.0.1:${toString alertmanagerPort}" ]; }
                  ];
                }
              ];
              scrapeConfigs = [
                {
                  job_name = "prometheus";
                  static_configs = [
                    { targets = [ "127.0.0.1:${toString prometheusPort}" ]; }
                  ];
                }
                {
                  job_name = "loki";
                  static_configs = [
                    { targets = [ "127.0.0.1:${toString lokiPort}" ]; }
                  ];
                }
              ];
              ruleFiles = [ alertRules ];
            };

            # ── Alert delivery ──
            services.prometheus.alertmanager = lib.mkIf ntfyDelivery.enable {
              enable = true;
              listenAddress = "127.0.0.1";
              port = alertmanagerPort;
              configuration = {
                global.resolve_timeout = "5m";
                route = {
                  receiver = "null";
                  group_by = [
                    "alertname"
                    "instance"
                    "severity"
                  ];
                  group_wait = "30s";
                  group_interval = "5m";
                  repeat_interval = "4h";
                  routes = [
                    {
                      receiver = "ntfy-critical";
                      matchers = [ ''severity="critical"'' ];
                      continue = false;
                      repeat_interval = "2h";
                    }
                  ];
                };
                receivers = [
                  { name = "null"; }
                  {
                    name = "ntfy-critical";
                    webhook_configs = [
                      {
                        url = "http://127.0.0.1:${toString alertmanagerNtfyPort}/hook";
                        send_resolved = true;
                      }
                    ];
                  }
                ];
              };
            };

            systemd.services.alertmanager-ntfy = lib.mkIf ntfyDelivery.enable {
              wants = [ "ntfy-sh.service" ];
              after = [ "ntfy-sh.service" ];
            };

            services.prometheus.alertmanager-ntfy = lib.mkIf ntfyDelivery.enable {
              enable = true;
              extraConfigFiles = [ ntfyBridgeConfig ];
              settings = {
                http.addr = "127.0.0.1:${toString alertmanagerNtfyPort}";
                ntfy = {
                  baseurl = ntfyDelivery.baseUrl;
                  async = false;
                  notification = {
                    inherit (ntfyDelivery) topic;
                    priority = ''status == "firing" ? "high" : "default"'';
                    tags = [
                      {
                        tag = "rotating_light";
                        condition = ''status == "firing"'';
                      }
                      {
                        tag = "white_check_mark";
                        condition = ''status == "resolved"'';
                      }
                    ];
                    templates = {
                      title = ''{{ if eq .Status "resolved" }}Resolved: {{ end }}{{ index .Labels "alertname" }}'';
                      description = ''
                        {{ index .Annotations "summary" }}

                        {{ index .Annotations "description" }}
                      '';
                    };
                  };
                };
              };
            };

            # ── Loki ──
            services.loki = {
              enable = true;
              configuration = {
                auth_enabled = false;
                analytics.reporting_enabled = false;

                server = {
                  http_listen_address = "127.0.0.1";
                  http_listen_port = lokiPort;
                  grpc_listen_address = "127.0.0.1";
                  grpc_listen_port = lokiGrpcPort;
                };

                common = {
                  path_prefix = config.services.loki.dataDir;
                  replication_factor = 1;
                  instance_addr = "127.0.0.1";
                  ring.kvstore.store = "inmemory";
                };

                schema_config.configs = [
                  {
                    from = "2026-01-01";
                    object_store = "filesystem";
                    schema = "v13";
                    store = "tsdb";
                    index = {
                      prefix = "index_";
                      period = "24h";
                    };
                  }
                ];

                storage_config.filesystem.directory = "${config.services.loki.dataDir}/chunks";

                limits_config = {
                  retention_period = "${toString settings.loki.retentionHours}h";
                  ingestion_rate_mb = 16;
                  ingestion_burst_size_mb = 32;
                  reject_old_samples = true;
                  reject_old_samples_max_age = "168h";
                  allow_structured_metadata = true;
                };

                compactor = {
                  working_directory = "${config.services.loki.dataDir}/compactor";
                  compaction_interval = "10m";
                  retention_enabled = true;
                  retention_delete_delay = "2h";
                  retention_delete_worker_count = 150;
                  delete_request_store = "filesystem";
                };
              };
            };

            # ── Grafana ──
            services.grafana = lib.mkIf settings.grafana.enable {
              enable = true;

              settings = {
                analytics = {
                  enabled = false;
                  reporting_enabled = false;
                  check_for_updates = false;
                  check_for_plugin_updates = false;
                  feedback_links_enabled = false;
                  news_feed_enabled = false;
                };

                dashboards.default_home_dashboard_path = "${dashboardPath}/network.json";

                database = {
                  type = "postgres";
                  host = "/run/postgresql";
                  user = "grafana";
                  name = "grafana";
                };

                metrics.enabled = false;
                public_dashboards.enabled = false;

                # Tailscale-only endpoint: network auth already gates access.
                # Anonymous Editor is intentional while the Atlas pages are
                # being designed. Provisioned dashboards stay read-only; use
                # Save as in the UI for scratch copies, then promote to git.
                "auth.anonymous" = {
                  enabled = true;
                  org_role = "Editor";
                  hide_version = true;
                };
                "auth".disable_login_form = true;

                plugins.preinstall_disabled = true;

                security = {
                  disable_gravatar = true;
                  secret_key = "$__file{/run/credentials/grafana.service/grafana-secret-key}";
                };

                users = {
                  default_theme = "dark";
                  home_page = "/d/atlas-network/network-router";
                  viewers_can_edit = false;
                };

                server = {
                  http_addr = "127.0.0.1";
                  http_port = grafanaPort;
                  domain = settings.host;
                  root_url = "http://${settings.host}/grafana/";
                  serve_from_sub_path = true;
                };

                snapshots = {
                  enabled = false;
                  external_enabled = false;
                };
              };

              provision = {
                enable = true;
                datasources.settings.datasources = [
                  {
                    name = "prometheus";
                    type = "prometheus";
                    uid = "prometheus";
                    url = "http://127.0.0.1:${toString prometheusPort}";
                    isDefault = true;
                    jsonData.manageAlerts = false;
                  }
                  {
                    name = "loki";
                    type = "loki";
                    uid = "loki";
                    url = "http://127.0.0.1:${toString lokiPort}";
                    jsonData.manageAlerts = false;
                  }
                ];
                dashboards.settings = {
                  apiVersion = 1;
                  providers = [
                    {
                      name = "atlas";
                      orgId = 1;
                      folder = "Atlas";
                      folderUid = "atlas";
                      type = "file";
                      disableDeletion = true;
                      allowUiUpdates = false;
                      updateIntervalSeconds = 30;
                      options.path = dashboardPath;
                    }
                  ];
                };
              };
            };

            systemd.services.grafana.serviceConfig = lib.mkIf settings.grafana.enable {
              LoadCredential = [
                "grafana-secret-key:${config.clan.core.vars.generators.grafana-secret.files.key.path}"
              ];
            };

            # ── Nginx reverse proxy ──
            # Credentials are symlinked into /run/nginx so basicAuthFile can see them.
            services.nginx = {
              enable = true;
              recommendedProxySettings = true;
              serverTokens = false;

              virtualHosts.${settings.host} = {
                locations = {
                  "/prometheus/" = {
                    basicAuthFile = "/run/nginx/credentials/prometheus-auth-htpasswd";
                    proxyPass = "http://127.0.0.1:${toString prometheusPort}/";
                    extraConfig = ''
                      client_max_body_size 32m;
                      proxy_read_timeout 120s;
                      proxy_send_timeout 120s;
                    '';
                  };

                  "/loki/" = {
                    basicAuthFile = "/run/nginx/credentials/loki-auth-htpasswd";
                    proxyPass = "http://127.0.0.1:${toString lokiPort}/";
                    extraConfig = ''
                      client_max_body_size 32m;
                      proxy_read_timeout 120s;
                      proxy_send_timeout 120s;
                    '';
                  };
                }
                // lib.optionalAttrs settings.grafana.enable {
                  # No trailing slash on proxyPass: Grafana has serve_from_sub_path
                  # = true and needs to see the full /grafana/... path, otherwise
                  # it redirect-loops trying to re-add the prefix.
                  "/grafana/" = {
                    proxyPass = "http://127.0.0.1:${toString grafanaPort}";
                    proxyWebsockets = true;
                  };

                  "= /" = {
                    return = "302 /grafana/";
                  };
                };
              };
            };

            systemd.services.nginx.serviceConfig.LoadCredential = [
              "prometheus-auth-htpasswd:${config.clan.core.vars.generators.prometheus-auth.files.htpasswd.path}"
              "loki-auth-htpasswd:${config.clan.core.vars.generators.loki-auth.files.htpasswd.path}"
            ];

            # nginx preStart runs as root and has access to $CREDENTIALS_DIRECTORY;
            # symlink makes the auth files readable to the worker processes.
            systemd.services.nginx.preStart = lib.mkAfter ''
              ln -sfn "$CREDENTIALS_DIRECTORY" /run/nginx/credentials
            '';
          };
      };
  };

  perMachine.nixosModule =
    { pkgs, ... }:
    {
      clan.core.vars.generators = {
        prometheus-auth = {
          share = true;
          files = {
            username.secret = false;
            password = { };
            htpasswd = { };
          };
          runtimeInputs = [
            pkgs.openssl
            pkgs.apacheHttpd
          ];
          script = ''
            echo -n "alloy" > "$out/username"
            openssl rand -hex 32 > "$out/password"
            htpasswd -nbB "$(cat "$out/username")" "$(cat "$out/password")" > "$out/htpasswd"
          '';
        };

        loki-auth = {
          share = true;
          files = {
            username.secret = false;
            password = { };
            htpasswd = { };
          };
          runtimeInputs = [
            pkgs.openssl
            pkgs.apacheHttpd
          ];
          script = ''
            echo -n "alloy" > "$out/username"
            openssl rand -hex 32 > "$out/password"
            htpasswd -nbB "$(cat "$out/username")" "$(cat "$out/password")" > "$out/htpasswd"
          '';
        };
      };
    };
}

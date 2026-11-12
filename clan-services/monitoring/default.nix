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
    "edac"
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
            inherit (lib)
              concatStringsSep
              escapeRegex
              optionalString
              ;

            machineName = config.clan.core.settings.machine.name;
            inherit (config.monitoring) textfileDirectory;

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

            # Alloy component labels must match [a-zA-Z_][a-zA-Z0-9_]*.
            scrapeTargetBlock = job: address: ''
              prometheus.scrape "target_${builtins.replaceStrings [ "-" ] [ "_" ] job}" {
                targets = [{
                  __address__ = "${address}",
                  instance    = "${machineName}",
                  job         = "${job}",
                }]
                honor_labels    = true
                forward_to      = [prometheus.remote_write.server.receiver]
                scrape_interval = "${settings.scrapeInterval}"
              }
            '';
            scrapeTargetBlocks = concatStringsSep "\n" (
              lib.mapAttrsToList scrapeTargetBlock config.monitoring.scrapeTargets
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
              prometheus.exporter.unix "local_system" {
                set_collectors = ${collectorsHCL}

                textfile {
                  directory = "${textfileDirectory}"
                }
              }

              // The server's alerts expect node metrics under the machine name, whatever the hostname.
              discovery.relabel "node" {
                targets = prometheus.exporter.unix.local_system.targets

                rule {
                  target_label = "instance"
                  replacement  = "${machineName}"
                }
              }

              prometheus.scrape "node" {
                targets         = discovery.relabel.node.output
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

              ${scrapeTargetBlocks}

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

            acmeCertificates = pkgs.writeText "acme-certificates" (
              lib.concatLines (
                lib.mapAttrsToList (name: cert: "${name}\t${cert.directory}/cert.pem") config.security.acme.certs
              )
            );

            acmeCertificateExpiry = pkgs.writeShellApplication {
              name = "acme-certificate-expiry";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.openssl
              ];
              text = ''
                out=${textfileDirectory}/acme-certificates.prom
                tmp=$(mktemp "$out.XXXXXX")
                trap 'rm -f "$tmp"' EXIT

                {
                  echo '# HELP acme_certificate_expiry_timestamp_seconds When the ACME certificate expires.'
                  echo '# TYPE acme_certificate_expiry_timestamp_seconds gauge'
                  while IFS=$'\t' read -r name path; do
                    if not_after=$(openssl x509 -enddate -noout -in "$path"); then
                      echo "acme_certificate_expiry_timestamp_seconds{certificate=\"$name\"} $(date -d "''${not_after#notAfter=}" +%s)"
                    fi
                  done < ${acmeCertificates}
                } > "$tmp"

                chmod 0644 "$tmp"
                mv "$tmp" "$out"
                trap - EXIT
              '';
            };
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

            systemd.services.acme-certificate-expiry = lib.mkIf (config.security.acme.certs != { }) {
              description = "Export ACME certificate expiry times for the metrics agent";
              startAt = "*:0/15";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe acmeCertificateExpiry;
              };
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
            example = "monitor.example.ts.net";
          };

          grafana.enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Grafana dashboards on this server.";
          };

          grafana.homeDashboard = lib.mkOption {
            type = lib.types.str;
            default = "fleet";
            description = ''
              Name of the dashboard Grafana opens on: `fleet`, this service's
              overview of every machine, or one an agent brings in its `dashboards`.
            '';
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

          alertDelivery.quietHours = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  start = lib.mkOption {
                    type = lib.types.strMatching "[0-2][0-9]:[0-5][0-9]";
                    description = "Local time, as `HH:MM`, at which warnings start waiting.";
                  };
                  end = lib.mkOption {
                    type = lib.types.strMatching "[0-2][0-9]:[0-5][0-9]";
                    description = "Local time, as `HH:MM`, at which held warnings go out.";
                  };
                };
              }
            );
            default = {
              start = "22:00";
              end = "08:00";
            };
            description = ''
              Window in this machine's time zone during which warnings wait;
              those still firing when it ends notify then. Critical alerts always
              notify at once. `null` sends warnings at any hour.
            '';
          };

          alertDelivery.ntfy = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Send alert notifications to ntfy through alertmanager-ntfy.";
            };

            baseUrl = lib.mkOption {
              type = lib.types.str;
              example = "http://127.0.0.1:2586";
              description = "Base URL of the ntfy server alerts are published to.";
            };

            topic = lib.mkOption {
              type = lib.types.str;
              example = "alerts";
              description = "ntfy topic for alert notifications.";
            };

            configGenerator = lib.mkOption {
              type = lib.types.str;
              example = "ntfy-alerts";
              description = ''
                Clan vars generator on this machine whose `alertmanager-ntfy.yml`
                file holds the ntfy credentials, as `ntfy.auth.token` or
                `ntfy.auth.basic`, for a user allowed to publish to the topic.
              '';
            };
          };
        };
      };

    perInstance =
      { settings, roles, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ports = {
              prometheus = 9090;
              alertmanager = 9093;
              ntfyBridge = 8000;
              loki = 3100;
              lokiGrpc = 9095;
              grafana = 3000;
            };

            machineName = config.clan.core.settings.machine.name;
            agents = roles.agent.machines;
            ntfyDelivery = settings.alertDelivery.ntfy;
            ntfyGenerator = config.clan.core.vars.generators.${ntfyDelivery.configGenerator} or null;
            ntfyBridgeConfig =
              if ntfyGenerator == null then
                throw "@adeci/monitoring: alertDelivery.ntfy requires clan vars generator '${ntfyDelivery.configGenerator}'"
              else
                ntfyGenerator.files."alertmanager-ntfy.yml".path;

            yaml = pkgs.formats.yaml { };
            rules = import ./rules.nix {
              inherit lib;
              alwaysOn = lib.attrNames (lib.filterAttrs (_: agent: agent.settings.alwaysOn) agents);
              machineRules = lib.mapAttrs (_: agent: agent.settings.rules) agents;
            };

            dashboards = lib.foldl' lib.attrsets.unionOfDisjoint (import ./dashboards) (
              lib.mapAttrsToList (_: agent: agent.settings.dashboards) agents
            );
            dashboardPath = pkgs.linkFarm "monitoring-grafana-dashboards" (
              lib.mapAttrsToList (name: dashboard: {
                name = "${name}.json";
                path = pkgs.writeText "monitoring-grafana-${name}.json" (builtins.toJSON dashboard);
              }) dashboards
            );
            homeDashboard =
              if dashboards ? ${settings.grafana.homeDashboard} then
                settings.grafana.homeDashboard
              else
                throw "@adeci/monitoring: grafana.homeDashboard '${settings.grafana.homeDashboard}' is none of the dashboards: ${lib.concatStringsSep ", " (lib.attrNames dashboards)}";
            grafanaUrl = config.services.grafana.settings.server.root_url;

            # The server's own exporters carry its machine name, like every agent's.
            localScrape = job: port: {
              job_name = job;
              static_configs = [
                {
                  targets = [ "127.0.0.1:${toString port}" ];
                  labels.instance = machineName;
                }
              ];
            };
          in
          {
            networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];

            clan.core.state.monitoring.folders = [
              "/var/lib/${config.services.prometheus.stateDir}"
              config.services.loki.dataDir
            ]
            ++ lib.optionals ntfyDelivery.enable [
              "/var/lib/alertmanager"
            ];

            clan.core.postgresql = lib.mkIf settings.grafana.enable {
              enable = true;
              users.grafana = { };
              databases.grafana = {
                create.options.OWNER = "grafana";
                restore.stopOnRestore = [ "grafana" ];
              };
            };

            # Grafana's NixOS module requires an explicit secret_key since 26.05; a generated one keeps stored secrets stable across rebuilds.
            clan.core.vars.generators = lib.optionalAttrs settings.grafana.enable {
              grafana-secret = {
                files.key = { };
                runtimeInputs = [ pkgs.openssl ];
                script = ''
                  openssl rand -hex 32 > "$out/key"
                '';
              };
            };

            services.prometheus = {
              enable = true;
              listenAddress = "127.0.0.1";
              port = ports.prometheus;
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
                    { targets = [ "127.0.0.1:${toString ports.alertmanager}" ]; }
                  ];
                }
              ];
              scrapeConfigs = [
                (localScrape "prometheus" ports.prometheus)
                (localScrape "loki" ports.loki)
              ];
              ruleFiles = [
                (yaml.generate "fleet-rules.yml" rules.fleet)
                (yaml.generate "machine-rules.yml" rules.machines)
              ];
            };

            services.prometheus.alertmanager = lib.mkIf ntfyDelivery.enable {
              enable = true;
              listenAddress = "127.0.0.1";
              port = ports.alertmanager;
              # A lone Alertmanager needs no gossip mesh, which fails to start before the network has an address.
              extraFlags = [ "--cluster.listen-address=" ];
              configuration = import ./alertmanager.nix {
                inherit lib;
                inherit (settings.alertDelivery) quietHours;
                webhookUrl = "http://127.0.0.1:${toString ports.ntfyBridge}/hook";
                timeZone = if config.time.timeZone == null then "UTC" else config.time.timeZone;
              };
            };

            systemd.services.alertmanager-ntfy = lib.mkIf ntfyDelivery.enable {
              wants = [ "ntfy-sh.service" ];
              after = [ "ntfy-sh.service" ];
            };

            services.prometheus.alertmanager-ntfy = lib.mkIf ntfyDelivery.enable {
              enable = true;
              extraConfigFiles = [ ntfyBridgeConfig ];
              settings = import ./ntfy-bridge.nix {
                inherit lib;
                inherit (ntfyDelivery) baseUrl topic;
                listenAddress = "127.0.0.1:${toString ports.ntfyBridge}";
                clickUrl = if settings.grafana.enable then "${grafanaUrl}d/${dashboards.fleet.uid}" else null;
              };
            };

            services.loki = {
              enable = true;
              configuration = {
                auth_enabled = false;
                analytics.reporting_enabled = false;

                server = {
                  http_listen_address = "127.0.0.1";
                  http_listen_port = ports.loki;
                  grpc_listen_address = "127.0.0.1";
                  grpc_listen_port = ports.lokiGrpc;
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

            services.grafana = lib.mkIf settings.grafana.enable {
              enable = true;
              # Grafana 13.2 ships these data sources as separate plugins.
              declarativePlugins = with pkgs.grafanaPlugins; [
                prometheus
                loki
              ];

              settings = {
                analytics = {
                  enabled = false;
                  reporting_enabled = false;
                  check_for_updates = false;
                  check_for_plugin_updates = false;
                  feedback_links_enabled = false;
                  news_feed_enabled = false;
                };

                dashboards.default_home_dashboard_path = "${dashboardPath}/${homeDashboard}.json";

                database = {
                  type = "postgres";
                  host = "/run/postgresql";
                  user = "grafana";
                  name = "grafana";
                };

                metrics.enabled = false;
                public_dashboards.enabled = false;

                # Tailnet-only, so anonymous Editor is fine while the dashboards are designed; provisioned ones stay read-only (Save as, then promote to git).
                "auth.anonymous" = {
                  enabled = true;
                  org_role = "Editor";
                  hide_version = true;
                };
                "auth".disable_login_form = true;

                security = {
                  disable_gravatar = true;
                  secret_key = "$__file{/run/credentials/grafana.service/grafana-secret-key}";
                };

                users = {
                  default_theme = "dark";
                  home_page = "/d/${dashboards.${homeDashboard}.uid}";
                  viewers_can_edit = false;
                };

                server = {
                  http_addr = "127.0.0.1";
                  http_port = ports.grafana;
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
                    url = "http://127.0.0.1:${toString ports.prometheus}";
                    isDefault = true;
                    jsonData.manageAlerts = false;
                  }
                  {
                    name = "loki";
                    type = "loki";
                    uid = "loki";
                    url = "http://127.0.0.1:${toString ports.loki}";
                    jsonData.manageAlerts = false;
                  }
                ];
                dashboards.settings = {
                  apiVersion = 1;
                  providers = [
                    {
                      name = "monitoring";
                      orgId = 1;
                      folder = "Monitoring";
                      folderUid = "monitoring";
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

            services.nginx = {
              enable = true;
              recommendedProxySettings = true;
              serverTokens = false;

              virtualHosts.${settings.host} = {
                locations = {
                  "/prometheus/" = {
                    basicAuthFile = "/run/nginx/credentials/prometheus-auth-htpasswd";
                    proxyPass = "http://127.0.0.1:${toString ports.prometheus}/";
                    extraConfig = ''
                      client_max_body_size 32m;
                      proxy_read_timeout 120s;
                      proxy_send_timeout 120s;
                    '';
                  };

                  "/loki/" = {
                    basicAuthFile = "/run/nginx/credentials/loki-auth-htpasswd";
                    proxyPass = "http://127.0.0.1:${toString ports.loki}/";
                    extraConfig = ''
                      client_max_body_size 32m;
                      proxy_read_timeout 120s;
                      proxy_send_timeout 120s;
                    '';
                  };
                }
                // lib.optionalAttrs settings.grafana.enable {
                  # No trailing slash: with serve_from_sub_path Grafana needs the full /grafana/ path, or it redirect-loops re-adding the prefix.
                  "/grafana/" = {
                    proxyPass = "http://127.0.0.1:${toString ports.grafana}";
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

            # preStart runs as root with $CREDENTIALS_DIRECTORY; the symlink lets nginx's workers read the auth files.
            systemd.services.nginx.preStart = lib.mkAfter ''
              ln -sfn "$CREDENTIALS_DIRECTORY" /run/nginx/credentials
            '';
          };
      };
  };

  perMachine.nixosModule =
    { lib, pkgs, ... }:
    {
      options.monitoring = {
        scrapeTargets = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Local Prometheus endpoints, as `address:port` by job name, that the agent scrapes and ships to the server.";
          example = {
            kea = "127.0.0.1:9547";
          };
        };

        textfileDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/alloy/textfile";
          readOnly = true;
          description = "Directory whose `*.prom` files the agent ships with the node metrics.";
        };
      };

      config.clan.core.vars.generators = {
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

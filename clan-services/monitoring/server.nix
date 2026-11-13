{
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
          ntfyCredentialsFile =
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
          dashboardDirectory = pkgs.linkFarm "monitoring-grafana-dashboards" (
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

          pushLocation = service: port: {
            basicAuthFile = "/run/nginx/credentials/${service}-auth-htpasswd";
            proxyPass = "http://127.0.0.1:${toString port}/";
            extraConfig = ''
              client_max_body_size 32m;
              proxy_read_timeout 120s;
              proxy_send_timeout 120s;
            '';
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
            extraConfigFiles = [ ntfyCredentialsFile ];
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
            declarativePlugins = [
              pkgs.grafanaPlugins.prometheus
              pkgs.grafanaPlugins.loki
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

              dashboards.default_home_dashboard_path = "${dashboardDirectory}/${homeDashboard}.json";

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
                    options.path = dashboardDirectory;
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
                "/prometheus/" = pushLocation "prometheus" ports.prometheus;
                "/loki/" = pushLocation "loki" ports.loki;
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
}

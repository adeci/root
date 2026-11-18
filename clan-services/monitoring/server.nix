{
  description = "Runs the monitoring server, with Prometheus, Alertmanager, Loki and Grafana, or a backup that alerts when it cannot";

  interface =
    { lib, ... }:
    {
      options = {
        host = lib.mkOption {
          type = lib.types.str;
          description = ''
            Fully qualified hostname every agent uses to reach this server. Must
            resolve to this machine from every agent — typically the Tailscale
            MagicDNS name. Also used as the nginx `server_name` agents push
            their journal to.
          '';
          example = "monitor.example.ts.net";
        };

        agentDomain = lib.mkOption {
          type = lib.types.str;
          description = ''
            Domain under which every agent answers as `<machine>.<domain>`,
            typically the tailnet's MagicDNS domain. The server scrapes each
            agent's exporters there.
          '';
          example = "example.ts.net";
        };

        backup = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            A backup server scrapes every agent and evaluates the same rules as
            the main server, and notifies through its own delivery when the
            main server has not: it is down, or its delivery fails. It keeps no
            logs and shows no dashboards, so only `agentDomain`, `retentionDays`
            and `alertDelivery` apply to it. One server of an instance is the
            main one.
          '';
        };

        grafana.domain = lib.mkOption {
          type = lib.types.str;
          description = ''
            Name Grafana is served under, at the root of its own nginx virtual
            host. Grafana's links use `https://` when the machine turns on TLS
            for that virtual host.
          '';
          example = "grafana.example.com";
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

        loki.retentionDays = lib.mkOption {
          type = lib.types.int;
          default = 7;
          description = "Loki log retention (days).";
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
          self,
          ...
        }:
        let
          ports = {
            prometheus = 9090;
            alertmanager = 9093;
            alertmanagerCluster = 9094;
            ntfyBridge = 8000;
            loki = 3100;
            lokiGrpc = 9095;
            grafana = 3000;
          };

          machineName = config.clan.core.settings.machine.name;
          agents = roles.agent.machines;
          ntfyDelivery = settings.alertDelivery.ntfy;
          main = !settings.backup;
          # The other servers, whose Alertmanagers form a cluster with this one's over the tailnet.
          peers = lib.attrNames (lib.removeAttrs roles.server.machines [ machineName ]);
          clustered = ntfyDelivery.enable && peers != [ ];
          tailnetAddress = machine: self.inventory.machines.${machine}.tailnet;
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

          dashboards = lib.foldl' lib.attrsets.unionOfDisjoint (import ./dashboards (
            lib.mapAttrs (machine: _: machineLabels machine) agents
          )) (lib.mapAttrsToList (_: agent: agent.settings.dashboards) agents);
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
          # The machine, not this service, turns on TLS for Grafana's virtual host.
          grafanaVirtualHost = config.services.nginx.virtualHosts.${settings.grafana.domain};
          grafanaTls = grafanaVirtualHost.forceSSL || grafanaVirtualHost.onlySSL || grafanaVirtualHost.addSSL;
          grafanaUrl = "${if grafanaTls then "https" else "http"}://${settings.grafana.domain}/";
          # A backup has no Grafana: its notifications open the main server's, which that server's assertion keeps on HTTPS.
          mainServer = lib.head (
            lib.filter (server: !server.settings.backup) (lib.attrValues roles.server.machines)
          );
          fleetPage = "${
            if main then grafanaUrl else "https://${mainServer.settings.grafana.domain}/"
          }d/${dashboards.fleet.uid}";

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

          # What the fleet dashboard filters machines on, from the inventory.
          machineLabels =
            machine:
            let
              inherit (self.inventory.machines.${machine}) class tags;
            in
            {
              os = if class == "darwin" then "macos" else "linux";
              kind = if lib.elem "portable" tags then "laptop" else "server";
            };

          # Every agent's exporters by job, reached over the tailnet under the machine name.
          agentJobs = lib.zipAttrs (
            lib.mapAttrsToList (
              machine: agent:
              lib.mapAttrs (_: port: {
                targets = [ "${machine}.${settings.agentDomain}:${toString port}" ];
                labels =
                  agent.settings.extraLabels
                  // machineLabels machine
                  // {
                    instance = machine;
                  };
              }) (agentExporters machine agent)
            ) agents
          );

          # The default ports of node_exporter, smartctl_exporter and blackbox_exporter; SMART comes from NixOS agents only.
          agentExporters =
            machine: agent:
            {
              node = 9100;
            }
            // lib.optionalAttrs ((machineLabels machine).os == "linux" && agent.settings.smart.enable) {
              smartctl = 9633;
            }
            // lib.optionalAttrs (agent.settings.probes != { }) {
              blackbox = 9115;
            }
            // agent.settings.exporters;

          # A probe is a scrape of its prober's blackbox_exporter; the __param labels tell it the address and the check.
          probes = lib.concatLists (
            lib.mapAttrsToList (
              machine: agent:
              lib.mapAttrsToList (name: probe: {
                targets = [
                  "${machine}.${settings.agentDomain}:${toString (agentExporters machine agent).blackbox}"
                ];
                labels = {
                  inherit name;
                  inherit (probe) instance;
                  __param_target = probe.url;
                  __param_module = if probe.redirect then "http_redirect" else "http_2xx";
                };
              }) agent.settings.probes
            ) agents
          );
        in
        {
          assertions = [
            {
              assertion = main && clustered -> grafanaTls;
              message = "@adeci/monitoring: a backup server's notifications link to Grafana over HTTPS, so ${machineName} must serve ${settings.grafana.domain} with TLS.";
            }
          ];

          networking.firewall.interfaces.tailscale0 = {
            allowedTCPPorts = lib.optional main 80 ++ lib.optional clustered ports.alertmanagerCluster;
            allowedUDPPorts = lib.optional clustered ports.alertmanagerCluster;
          };

          # The silences, which a backup server only copies; metrics and logs refill as the machines report.
          # Alertmanager runs under a dynamic user, so /var/lib/alertmanager is only a link to this folder.
          clan.core.state = lib.mkIf (main && ntfyDelivery.enable) {
            monitoring.folders = [ "/var/lib/private/alertmanager" ];
          };

          clan.core.postgresql = lib.mkIf main {
            enable = true;
            users.grafana = { };
            databases.grafana = {
              create.options.OWNER = "grafana";
              restore.stopOnRestore = [ "grafana" ];
            };
          };

          clan.core.vars.generators = lib.optionalAttrs main {
            # Grafana's NixOS module requires an explicit secret_key since 26.05; a generated one keeps stored secrets stable across rebuilds.
            grafana-secret = {
              files.key = { };
              runtimeInputs = [ pkgs.openssl ];
              script = ''
                openssl rand -hex 32 > "$out/key"
              '';
            };

            grafana-admin = {
              files.password = { };
              runtimeInputs = [ pkgs.xkcdpass ];
              script = ''
                xkcdpass --numwords 6 --delimiter - > "$out/password"
              '';
            };
          };

          services.prometheus = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = ports.prometheus;
            retentionTime = "${toString settings.retentionDays}d";
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
            ]
            ++ lib.optional main (localScrape "loki" ports.loki)
            ++ lib.optionals ntfyDelivery.enable [
              (localScrape "alertmanager" ports.alertmanager)
            ]
            ++ lib.mapAttrsToList (job: staticConfigs: {
              job_name = job;
              static_configs = staticConfigs;
            }) agentJobs
            ++ lib.optional (probes != [ ]) {
              job_name = "probe";
              metrics_path = "/probe";
              # Every scrape is a request to the name, and each server scrapes.
              scrape_interval = "1m";
              static_configs = probes;
            };
            ruleFiles = [
              (yaml.generate "fleet-rules.yml" rules.fleet)
              (yaml.generate "machine-rules.yml" rules.machines)
            ];
          };

          services.prometheus.alertmanager = lib.mkIf ntfyDelivery.enable {
            enable = true;
            listenAddress = "127.0.0.1";
            port = ports.alertmanager;
            clusterPeers = map tailnetAddress peers;
            extraFlags =
              if clustered then
                [
                  "--cluster.advertise-address=${tailnetAddress machineName}:${toString ports.alertmanagerCluster}"
                  # Peers notify in the order of their names, each 15 seconds after the one before and only what is still unsent: the main server first.
                  "--cluster.peer-name=${if main then "1" else "2"}-${machineName}"
                ]
              else
                # A lone Alertmanager needs no gossip mesh, which fails to start before the network has an address.
                [ "--cluster.listen-address=" ];
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
              inherit (ntfyDelivery) baseUrl topic;
              listenAddress = "127.0.0.1:${toString ports.ntfyBridge}";
              clickUrl = fleetPage;
            };
          };

          services.loki = lib.mkIf main {
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
                retention_period = "${toString (settings.loki.retentionDays * 24)}h";
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

          services.grafana = lib.mkIf main {
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

              security = {
                disable_gravatar = true;
                secret_key = "$__file{/run/credentials/grafana.service/grafana-secret-key}";
                # Grafana takes this when it first creates its database; `grafana cli admin reset-admin-password` changes it later.
                admin_password = "$__file{/run/credentials/grafana.service/grafana-admin-password}";
                cookie_secure = grafanaTls;
              };

              users = {
                default_theme = "dark";
                home_page = "/d/${dashboards.${homeDashboard}.uid}";
                viewers_can_edit = false;
              };

              server = {
                http_addr = "127.0.0.1";
                http_port = ports.grafana;
                inherit (settings.grafana) domain;
                root_url = grafanaUrl;
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

          systemd.services.grafana.serviceConfig = lib.mkIf main {
            LoadCredential = [
              "grafana-secret-key:${config.clan.core.vars.generators.grafana-secret.files.key.path}"
              "grafana-admin-password:${config.clan.core.vars.generators.grafana-admin.files.password.path}"
            ];
          };

          services.nginx = lib.mkIf main {
            enable = true;
            recommendedProxySettings = true;
            serverTokens = false;

            virtualHosts = lib.mkMerge [
              {
                # Agents push their journal here and nowhere else: the rest of Loki's API reads and deletes logs.
                ${settings.host}.locations."= /loki/loki/api/v1/push" = {
                  basicAuthFile = "/run/nginx/credentials/loki-auth-htpasswd";
                  proxyPass = "http://127.0.0.1:${toString ports.loki}/loki/api/v1/push";
                  extraConfig = ''
                    client_max_body_size 32m;
                    proxy_read_timeout 120s;
                    proxy_send_timeout 120s;
                  '';
                };
              }
              {
                ${settings.grafana.domain}.locations."/" = {
                  proxyPass = "http://127.0.0.1:${toString ports.grafana}";
                  proxyWebsockets = true;
                };
              }
            ];
          };

          systemd.services.nginx = lib.mkIf main {
            serviceConfig.LoadCredential = [
              "loki-auth-htpasswd:${config.clan.core.vars.generators.loki-auth.files.htpasswd.path}"
            ];
            # preStart runs as root with $CREDENTIALS_DIRECTORY; the symlink lets nginx's workers read the auth files.
            preStart = lib.mkAfter ''
              ln -sfn "$CREDENTIALS_DIRECTORY" /run/nginx/credentials
            '';
          };
        };
    };
}

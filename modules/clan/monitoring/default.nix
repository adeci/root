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

            extraLabelPairs = lib.mapAttrsToList (n: v: "  \"${n}\" = \"${v}\",") settings.extraLabels;
            extraLabelsHCL = concatStringsSep "\n" extraLabelPairs;

            extraRelabelRules = concatStringsSep "\n" settings.journal.relabelRules;

            alloyConfig = builtins.toFile "config.alloy" ''
              // ───────── Metrics ─────────

              prometheus.exporter.unix "local_system" {
                set_collectors = ${collectorsHCL}

                textfile {
                  directory = "/var/lib/alloy/textfile"
                }
              }

              prometheus.scrape "node" {
                targets         = prometheus.exporter.unix.local_system.targets
                forward_to      = [prometheus.remote_write.server.receiver]
                scrape_interval = "${settings.scrapeInterval}"
              }

              prometheus.scrape "alloy_self" {
                targets         = [{__address__ = "127.0.0.1:12345", job = "alloy"}]
                forward_to      = [prometheus.remote_write.server.receiver]
                scrape_interval = "${settings.scrapeInterval}"
              }

              prometheus.remote_write "server" {
                external_labels = {
                  "machine" = "${machineName}",
              ${extraLabelsHCL}
                }

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
                external_labels = {
                  "machine" = "${machineName}",
              ${extraLabelsHCL}
                }

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
            lokiPort = 3100;
            lokiGrpcPort = 9095;
            grafanaPort = 3000;

            alertRules = pkgs.writeText "adeci-monitoring-alerts.yml" ''
              groups:
                - name: fleet
                  rules:
                    - alert: HostStale
                      expr: |
                        (time() - max by (machine) (timestamp(node_uname_info))) > 180
                      for: 0m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Host {{ $labels.machine }} has not reported metrics for 3+ minutes"
                        description: "No samples received from {{ $labels.machine }} in the last 3 minutes. Agent down, network issue, or host offline."

                    - alert: DiskSpaceHigh
                      expr: |
                        100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}
                                 / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}) > 90
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Filesystem {{ $labels.mountpoint }} on {{ $labels.machine }} is over 90% full"

                    - alert: DiskSpaceCritical
                      expr: |
                        100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}
                                 / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}) > 95
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Filesystem {{ $labels.mountpoint }} on {{ $labels.machine }} is over 95% full"

                    - alert: InodeExhaustionHigh
                      expr: |
                        100 * (1 - node_filesystem_files_free{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}
                                 / node_filesystem_files{fstype!~"tmpfs|fuse.lxcfs|nsfs|overlay|squashfs|ramfs|devtmpfs"}) > 90
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Filesystem {{ $labels.mountpoint }} on {{ $labels.machine }} is over 90% inode-full"

                    - alert: SystemdUnitFailed
                      expr: node_systemd_unit_state{state="failed"} == 1
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Systemd unit {{ $labels.name }} on {{ $labels.machine }} has been failed for 5+ minutes"

                - name: stack-health
                  rules:
                    - alert: AlloyWriteFailing
                      expr: |
                        sum by (machine) (rate(prometheus_remote_write_samples_failed_total[5m])) > 0
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Alloy agent on {{ $labels.machine }} is failing remote_write requests"

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
            '';
          in
          {
            # ── Firewall: only allow port 80 over Tailscale ──
            networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];

            # ── State folders (survive clan state restore) ──
            clan.core.state.monitoring.folders = [
              "/var/lib/${config.services.prometheus.stateDir}"
              config.services.loki.dataDir
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

            # ── Server-only generators ──
            clan.core.vars.generators = lib.optionalAttrs settings.grafana.enable {
              grafana-admin = {
                prompts.username.description = "Grafana admin username";
                files = {
                  username.secret = false;
                  password = { };
                };
                runtimeInputs = [ pkgs.openssl ];
                script = ''
                  cat "$prompts/username" > "$out/username"
                  openssl rand -hex 32 > "$out/password"
                '';
              };
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
                };

                database = {
                  type = "postgres";
                  host = "/run/postgresql";
                  user = "grafana";
                  name = "grafana";
                };

                metrics.enabled = false;
                public_dashboards.enabled = false;

                security = {
                  admin_user = "$__file{/run/credentials/grafana.service/grafana-admin-username}";
                  admin_password = "$__file{/run/credentials/grafana.service/grafana-admin-password}";
                  secret_key = "$__file{/run/credentials/grafana.service/grafana-secret-key}";
                  cookie_secure = false;
                  csrf_trusted_origins = settings.host;
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

                dashboards.settings.providers = [
                  {
                    name = "adeci";
                    options.path = ./dashboards;
                    foldersFromFilesStructure = false;
                    allowUiUpdates = false;
                  }
                ];

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
              };
            };

            systemd.services.grafana.serviceConfig = lib.mkIf settings.grafana.enable {
              LoadCredential = [
                "grafana-admin-username:${config.clan.core.vars.generators.grafana-admin.files.username.path}"
                "grafana-admin-password:${config.clan.core.vars.generators.grafana-admin.files.password.path}"
                "grafana-secret-key:${config.clan.core.vars.generators.grafana-secret.files.key.path}"
              ];
            };

            # ── Nginx reverse proxy ──
            # Credentials are symlinked into /run/nginx so basicAuthFile can see them.
            services.nginx = {
              enable = true;
              recommendedProxySettings = true;
              serverTokens = false;

              commonHttpConfig = ''
                # Prometheus remote-write bursts can be large
                client_max_body_size 32m;
              '';

              virtualHosts.${settings.host} = {
                locations = {
                  "/prometheus/" = {
                    basicAuthFile = "/run/nginx/credentials/prometheus-auth-htpasswd";
                    proxyPass = "http://127.0.0.1:${toString prometheusPort}/";
                    extraConfig = ''
                      proxy_read_timeout 120s;
                      proxy_send_timeout 120s;
                    '';
                  };

                  "/loki/" = {
                    basicAuthFile = "/run/nginx/credentials/loki-auth-htpasswd";
                    proxyPass = "http://127.0.0.1:${toString lokiPort}/";
                    extraConfig = ''
                      proxy_read_timeout 120s;
                      proxy_send_timeout 120s;
                    '';
                  };
                }
                // lib.optionalAttrs settings.grafana.enable {
                  "/grafana/" = {
                    proxyPass = "http://127.0.0.1:${toString grafanaPort}/";
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

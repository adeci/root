{ inputs }:
_:
let
  workerPasswordSourceName =
    instanceName: machineName: "${instanceName}-worker-password-${machineName}";
  workerRuntimeSecretName = instanceName: machineName: "${instanceName}-worker-${machineName}";

  sharedWorkerPasswordGenerator = pkgs: {
    share = true;
    files.password.deploy = false;
    runtimeInputs = [ pkgs.pwgen ];
    script = # bash
      ''
        pwgen -s 32 1 | tr -d '\n' > "$out"/password
      '';
  };

  workerRuntimeSecretGenerator = passwordSourceName: {
    dependencies = [ passwordSourceName ];
    files.password = { };
    script = # bash
      ''
        cp "$in"/${passwordSourceName}/password "$out"/password
      '';
  };
in
{
  _class = "clan.service";

  manifest = {
    name = "@adeci/buildbot";
    description = "Buildbot-nix master and worker coordination";
    categories = [ "System" ];
    readme = builtins.readFile ./README.md;
  };

  roles.master = {
    description = "Buildbot-nix master, web frontend, GitHub integration, and worker registry";

    interface =
      { lib, ... }:
      {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = "Public Buildbot domain";
            example = "buildbot.example.com";
          };

          useHTTPS = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether the public Buildbot URL uses HTTPS";
          };

          buildSystems = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = "Systems Buildbot evaluates/builds. Defaults to the union of worker systems.";
          };

          evalWorkerCount = lib.mkOption {
            type = lib.types.int;
            default = 4;
            description = "Number of buildbot-nix evaluator workers";
          };

          evalMaxMemorySize = lib.mkOption {
            type = lib.types.int;
            default = 4096;
            description = "Maximum memory per evaluator worker, in MiB";
          };

          admins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Buildbot admin GitHub usernames";
          };

          workerPort = lib.mkOption {
            type = lib.types.port;
            default = 9989;
            description = "Buildbot worker TCP port";
          };

          openWorkerPortOnTailscale = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Open the worker TCP port on tailscale0 when remote workers exist";
          };

          github.appId = lib.mkOption {
            type = lib.types.int;
            description = "GitHub App ID";
          };

          github.oauthId = lib.mkOption {
            type = lib.types.str;
            description = "GitHub OAuth App client ID";
          };

          github.topic = lib.mkOption {
            type = lib.types.str;
            default = "build-with-buildbot";
            description = "GitHub topic used by buildbot-nix for repository discovery";
          };
        };
      };

    perInstance =
      {
        instanceName,
        roles,
        settings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            inherit (lib)
              attrNames
              concatMapStringsSep
              escapeShellArg
              listToAttrs
              mkIf
              unique
              ;

            machineName = config.clan.core.settings.machine.name;
            workerMachines = roles.worker.machines or { };
            workerMachineNames = attrNames workerMachines;
            remoteWorkers = builtins.filter (name: name != machineName) workerMachineNames;

            workerEntries = map (
              workerMachineName:
              let
                workerSettings = workerMachines.${workerMachineName}.settings;
                workerName = if workerSettings.name != null then workerSettings.name else workerMachineName;
              in
              {
                machineName = workerMachineName;
                name = workerName;
                inherit (workerSettings) cores systems;
                passwordSourceName = workerPasswordSourceName instanceName workerMachineName;
              }
            ) workerMachineNames;

            buildSystems =
              if settings.buildSystems != null then
                settings.buildSystems
              else
                unique (builtins.concatMap (worker: worker.systems) workerEntries);

            workerGenerators = listToAttrs (
              map (worker: {
                name = worker.passwordSourceName;
                value = sharedWorkerPasswordGenerator pkgs;
              }) workerEntries
            );
          in
          {
            imports = [ inputs.buildbot-nix.nixosModules.buildbot-master ];

            assertions = [
              {
                assertion = workerMachineNames != [ ];
                message = "@adeci/buildbot: master has no workers. Add machines to roles.worker.";
              }
              {
                assertion = buildSystems != [ ];
                message = "@adeci/buildbot: master buildSystems is empty.";
              }
            ];

            clan.core.vars.generators = workerGenerators // {
              "${instanceName}-workers" = {
                dependencies = map (worker: worker.passwordSourceName) workerEntries;
                files."workers.json" = { };
                runtimeInputs = [ pkgs.jq ];
                script = # bash
                ''
                  workers_file="$out/workers.json"
                  jq -n '[]' > "$workers_file"
                ''
                + concatMapStringsSep "\n" (worker: ''
                  tmp=$(mktemp)
                  jq \
                    --arg name ${escapeShellArg worker.name} \
                    --arg pass "$(cat "$in"/${worker.passwordSourceName}/password)" \
                    --argjson cores ${toString worker.cores} \
                    '. + [{"name": $name, "pass": $pass, "cores": $cores}]' \
                    "$workers_file" > "$tmp"
                  mv "$tmp" "$workers_file"
                '') workerEntries;
              };

              "${instanceName}-webhook-secret" = {
                files.webhook-secret = { };
                runtimeInputs = [ pkgs.openssl ];
                script = # bash
                  ''
                    openssl rand -hex 32 | tr -d '\n' > "$out"/webhook-secret
                  '';
              };

              "${instanceName}-github" = {
                files = {
                  app-secret-key = { };
                  oauth-secret = { };
                };
                prompts = {
                  app-secret-key = {
                    description = "GitHub App private key (PEM) for buildbot-nix";
                    type = "multiline-hidden";
                    persist = true;
                  };
                  oauth-secret = {
                    description = "GitHub OAuth App client secret for buildbot-nix";
                    type = "hidden";
                    persist = true;
                  };
                };
                runtimeInputs = [ pkgs.coreutils ];
                script = # bash
                  ''
                    cat "$prompts"/app-secret-key > "$out"/app-secret-key
                    cat "$prompts"/oauth-secret > "$out"/oauth-secret
                  '';
              };
            };

            clan.core.state.buildbot-master = {
              folders = [ "/var/lib/buildbot" ];
              preRestoreScript = ''
                ${config.systemd.package}/bin/systemctl stop buildbot-master.service
              '';
              postRestoreScript = ''
                ${config.systemd.package}/bin/systemctl start buildbot-master.service
              '';
            };

            # Buildbot is served through the Cloudflare tunnel. Keep nginx bound
            # to loopback so the web UI is not exposed on the LAN.
            services.nginx.virtualHosts.${settings.domain} = {
              listen = [
                {
                  addr = "127.0.0.1";
                  port = 80;
                }
                {
                  addr = "[::1]";
                  port = 80;
                }
              ];
              extraConfig = ''
                if ($http_x_forwarded_proto = "http") {
                  return 301 https://$host$request_uri;
                }
              '';
            };

            services.buildbot-nix.master = {
              enable = true;
              inherit (settings)
                admins
                domain
                evalMaxMemorySize
                evalWorkerCount
                useHTTPS
                ;
              inherit buildSystems;
              workersFile = config.clan.core.vars.generators."${instanceName}-workers".files."workers.json".path;
              github = {
                inherit (settings.github)
                  appId
                  oauthId
                  topic
                  ;
                appSecretKeyFile =
                  config.clan.core.vars.generators."${instanceName}-github".files.app-secret-key.path;
                webhookSecretFile =
                  config.clan.core.vars.generators."${instanceName}-webhook-secret".files.webhook-secret.path;
                oauthSecretFile = config.clan.core.vars.generators."${instanceName}-github".files.oauth-secret.path;
              };
            };

            networking.firewall.interfaces.tailscale0.allowedTCPPorts = mkIf (
              settings.openWorkerPortOnTailscale && remoteWorkers != [ ]
            ) [ settings.workerPort ];
          };
      };
  };

  roles.worker = {
    description = "Buildbot-nix worker that executes builds for the master";

    interface =
      { lib, ... }:
      {
        options = {
          name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Buildbot worker name. Defaults to the machine name.";
          };

          systems = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "x86_64-linux" ];
            description = "Systems this worker contributes to the master's buildSystems default.";
          };

          cores = lib.mkOption {
            type = lib.types.int;
            default = 1;
            description = "Core count advertised to Buildbot and worker concurrency.";
          };

          masterUrl = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override Buildbot master URL. Defaults to localhost on the master, otherwise the tailnet host.";
          };

          enableDistributedBuilds = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable Nix remote-builder routing for Buildbot jobs scheduled on this worker.";
          };
        };
      };

    perInstance =
      {
        instanceName,
        roles,
        settings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            inherit (lib)
              attrNames
              concatStringsSep
              head
              unique
              ;
            inherit (config.clan.core.settings) domain;

            machineName = config.clan.core.settings.machine.name;
            masterNames = attrNames (roles.master.machines or { });
            masterName = head masterNames;
            masterSettings = roles.master.machines.${masterName}.settings;
            workerMachines = roles.worker.machines or { };
            masterBuildSystems =
              if masterSettings.buildSystems != null then
                masterSettings.buildSystems
              else
                unique (
                  builtins.concatMap (name: workerMachines.${name}.settings.systems) (attrNames workerMachines)
                );
            missingLocalSystems = builtins.filter (
              system: !(builtins.elem system settings.systems)
            ) masterBuildSystems;
            remoteBuildSystems = unique (
              builtins.concatMap (builder: builder.systems) config.nix.buildMachines
            );
            missingRemoteSystems = builtins.filter (
              system: !(builtins.elem system remoteBuildSystems)
            ) missingLocalSystems;
            isMaster = machineName == masterName;
            dotDomain = if domain != null then ".${domain}" else "";
            workerName = if settings.name != null then settings.name else machineName;
            passwordSourceName = workerPasswordSourceName instanceName machineName;
            runtimeSecretName = workerRuntimeSecretName instanceName machineName;
            masterUrl =
              if settings.masterUrl != null then
                settings.masterUrl
              else if isMaster then
                "tcp:host=localhost:port=${toString masterSettings.workerPort}"
              else
                "tcp:host=${masterName}${dotDomain}:port=${toString masterSettings.workerPort}";
          in
          {
            imports = [ inputs.buildbot-nix.nixosModules.buildbot-worker ];

            assertions = [
              {
                assertion = builtins.length masterNames == 1;
                message = "@adeci/buildbot: workers require exactly one master, got ${toString (builtins.length masterNames)}.";
              }
              {
                assertion = missingLocalSystems == [ ] || settings.enableDistributedBuilds;
                message = "@adeci/buildbot: ${machineName} cannot locally build ${concatStringsSep ", " missingLocalSystems}; enable distributed builds or reduce master buildSystems.";
              }
              {
                assertion = missingRemoteSystems == [ ];
                message = "@adeci/buildbot: ${machineName} lacks remote builders for ${concatStringsSep ", " missingRemoteSystems}; add matching @adeci/remote-builder servers/clients.";
              }
            ];

            clan.core.vars.generators = {
              ${runtimeSecretName} = workerRuntimeSecretGenerator passwordSourceName;
            }
            // lib.optionalAttrs (!isMaster) {
              ${passwordSourceName} = sharedWorkerPasswordGenerator pkgs;
            };

            # buildbot-nix can schedule any configured system on any worker;
            # Nix buildMachines provide the per-architecture routing.
            nix.distributedBuilds = lib.mkIf settings.enableDistributedBuilds (lib.mkDefault true);

            services.buildbot-nix.worker = {
              enable = true;
              name = workerName;
              workerPasswordFile = config.clan.core.vars.generators.${runtimeSecretName}.files.password.path;
              inherit masterUrl;
              workers = settings.cores;
            };
          };
      };
  };
}

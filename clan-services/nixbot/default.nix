{ inputs }:
_: {
  _class = "clan.service";

  manifest = {
    name = "@adeci/nixbot";
    description = "Nixbot CI server with GitHub integration";
    categories = [ "System" ];
    readme = builtins.readFile ./README.md;
  };

  roles.server = {
    description = "Nixbot service, web frontend and GitHub App integration";

    interface =
      { lib, ... }:
      {
        options = {
          domain = lib.mkOption {
            type = lib.types.str;
            description = "Public nixbot domain";
            example = "nixbot.example.com";
          };

          useHTTPS = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether the public URL uses HTTPS";
          };

          buildSystems = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Systems to build; anything this machine can't build goes to its nix remote builders";
          };

          evalWorkerCount = lib.mkOption {
            type = lib.types.int;
            default = 4;
            description = "Number of nix-eval-jobs workers";
          };

          evalMaxMemorySize = lib.mkOption {
            type = lib.types.int;
            default = 4096;
            description = "Maximum memory per evaluation worker, in MiB";
          };

          buildConcurrency = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Cap on concurrent attribute builds; null means the CPU count";
          };

          admins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Provider-qualified admins, e.g. github:<login>";
          };

          prApproval.enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Hold pull requests from outside contributors until a repo writer approves CI";
          };

          prApproval.trustedAssociations = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "OWNER"
              "MEMBER"
              "COLLABORATOR"
              "CONTRIBUTOR"
            ];
            description = "GitHub author_association values that build without approval";
          };

          github.appId = lib.mkOption {
            type = lib.types.int;
            description = "GitHub App ID";
          };

          github.oauthId = lib.mkOption {
            type = lib.types.str;
            description = "GitHub App OAuth client ID";
          };

          github.userAllowlist = lib.mkOption {
            type = lib.types.nullOr (lib.types.listOf lib.types.str);
            default = null;
            description = "If non-null, only repositories owned by these GitHub users/organizations are built";
          };

          effectSecrets = lib.mkOption {
            type = lib.types.attrsOf (lib.types.listOf (lib.types.strMatching "[A-Za-z_][A-Za-z0-9_]*"));
            default = { };
            example = {
              "github:owner/repo" = [ "cachix" ];
            };
            description = "Prompted effect secrets per repo; effects read each with `readSecretString <name> .token`";
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            generators = config.clan.core.vars.generators;
            effectSecretsGenerator =
              repo: "${instanceName}-effects-${lib.replaceStrings [ ":" "/" ] [ "-" "-" ] repo}";
          in
          {
            imports = [
              inputs.nixbot.nixosModules.nixbot
              ./build-egress.nix
            ];

            clan.core.vars.generators = {
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
                    description = "GitHub App private key (PEM)";
                    type = "multiline-hidden";
                    persist = true;
                  };
                  oauth-secret = {
                    description = "GitHub App OAuth client secret";
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
            }
            // lib.mapAttrs' (
              repo: names:
              lib.nameValuePair (effectSecretsGenerator repo) {
                files.secrets = { };
                prompts = lib.genAttrs names (name: {
                  description = "${repo} effect secret `${name}`";
                  type = "hidden";
                  persist = true;
                });
                runtimeInputs = [ pkgs.jq ];
                script = # bash
                  ''
                    json='{}'
                    ${lib.concatMapStrings (name: ''
                      json=$(jq --rawfile v "$prompts"/${name} '.${name}.data.token = ($v | rtrimstr("\n"))' <<<"$json")
                    '') names}
                    printf '%s' "$json" > "$out"/secrets
                  '';
              }
            ) settings.effectSecrets;

            clan.core.state.nixbot = {
              folders = [ "/var/lib/nixbot" ];
              preRestoreScript = ''
                ${config.systemd.package}/bin/systemctl stop nixbot.service
              '';
              postRestoreScript = ''
                ${config.systemd.package}/bin/systemctl start nixbot.service
              '';
            };

            # Served through the Cloudflare tunnel; keep nginx on loopback.
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

            services.nixbot = {
              enable = true;
              inherit (settings)
                admins
                buildConcurrency
                buildSystems
                domain
                evalMaxMemorySize
                evalWorkerCount
                useHTTPS
                ;
              prApproval = { inherit (settings.prApproval) enable trustedAssociations; };
              github = {
                enable = true;
                inherit (settings.github) appId oauthId userAllowlist;
                # Projects are enabled in the web UI, not by topic.
                topic = null;
                appSecretKeyFile = generators."${instanceName}-github".files.app-secret-key.path;
                webhookSecretFile = generators."${instanceName}-webhook-secret".files.webhook-secret.path;
                oauthSecretFile = generators."${instanceName}-github".files.oauth-secret.path;
              };
              effects.perRepoSecretFiles = lib.mapAttrs (
                repo: _: generators.${effectSecretsGenerator repo}.files.secrets.path
              ) settings.effectSecrets;
            };

            # Builds go through this machine's nix daemon; other systems use
            # its @adeci/remote-builder machines.
            nix.distributedBuilds = lib.mkDefault true;
          };
      };
  };
}

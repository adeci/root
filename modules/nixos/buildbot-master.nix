{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.adeci.buildbot-master;
in
{
  options.adeci.buildbot-master = {
    enable = lib.mkEnableOption "Buildbot CI master (controller, web UI, GitHub integration)";

    admins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of GitHub usernames with admin access to the Buildbot web UI.";
    };

    github = {
      appId = lib.mkOption {
        type = lib.types.int;
        description = "GitHub App ID for buildbot-nix integration.";
      };

      oauthId = lib.mkOption {
        type = lib.types.str;
        description = "GitHub OAuth App client ID for buildbot-nix authentication.";
      };
    };

    evalWorkerCount = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Number of parallel nix-eval-jobs workers. Null uses the upstream default.";
    };
  };

  imports = [
    inputs.buildbot-nix.nixosModules.buildbot-master
  ];

  config = lib.mkIf cfg.enable {
    # Vars generator: GitHub App secrets (prompted)
    clan.core.vars.generators.buildbot-github = {
      share = true;
      files = {
        app-secret-key = { };
        webhook-secret = { };
        oauth-secret = { };
      };
      prompts = {
        app-secret-key = {
          description = "GitHub App private key (PEM) for buildbot-nix";
          type = "multiline-hidden";
          persist = true;
        };
        webhook-secret = {
          description = "GitHub App webhook secret for buildbot-nix";
          type = "hidden";
          persist = true;
        };
        oauth-secret = {
          description = "GitHub OAuth App client secret for buildbot-nix";
          type = "hidden";
          persist = true;
        };
      };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''
        cat "$prompts"/app-secret-key > "$out"/app-secret-key
        cat "$prompts"/webhook-secret > "$out"/webhook-secret
        cat "$prompts"/oauth-secret > "$out"/oauth-secret
      '';
    };

    # Vars generator: worker credentials (auto-generated)
    clan.core.vars.generators.buildbot-workers = {
      share = true;
      files = {
        password = { };
        "workers.json" = { };
      };
      runtimeInputs = with pkgs; [
        pwgen
        jq
      ];
      script = ''
        pwgen -s 32 1 | tr -d '\n' > "$out"/password
        PASSWORD=$(cat "$out"/password)
        jq -n --arg pass "$PASSWORD" \
          '[{"name":"leviathan","pass":$pass,"cores":128}]' \
          > "$out"/workers.json
      '';
    };

    services.buildbot-nix.master = {
      enable = true;
      domain = "buildbot.decio.us";
      useHTTPS = true;
      buildSystems = [ "x86_64-linux" ];
      workersFile = config.clan.core.vars.generators.buildbot-workers.files."workers.json".path;
      inherit (cfg) admins;
      inherit (cfg) evalWorkerCount;
      github = {
        inherit (cfg.github) appId oauthId;
        appSecretKeyFile = config.clan.core.vars.generators.buildbot-github.files.app-secret-key.path;
        webhookSecretFile = config.clan.core.vars.generators.buildbot-github.files.webhook-secret.path;
        oauthSecretFile = config.clan.core.vars.generators.buildbot-github.files.oauth-secret.path;
        topic = "build-with-buildbot";
      };
    };

  };
}

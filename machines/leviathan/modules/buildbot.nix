{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.buildbot-nix.nixosModules.buildbot-master
    inputs.buildbot-nix.nixosModules.buildbot-worker
  ];

  # Worker password (leviathan is its own worker)
  clan.core.vars.generators = {
    buildbot-worker-leviathan = {
      share = true;
      files.password = { };
      runtimeInputs = [ pkgs.pwgen ];
      script = ''
        pwgen -s 32 1 | tr -d '\n' > "$out"/password
      '';
    };

    buildbot-workers = {
      dependencies = [ "buildbot-worker-leviathan" ];
      files."workers.json" = { };
      runtimeInputs = [ pkgs.jq ];
      script = ''
        pass=$(cat "$in/buildbot-worker-leviathan/password")
        jq -n --arg pass "$pass" \
          '[{"name":"leviathan","pass":$pass,"cores":32}]' \
          > "$out/workers.json"
      '';
    };

    # Webhook secret — auto-generated
    buildbot-webhook-secret = {
      share = true;
      files.webhook-secret = { };
      runtimeInputs = [ pkgs.openssl ];
      script = ''
        openssl rand -hex 32 | tr -d '\n' > "$out"/webhook-secret
      '';
    };

    # GitHub App secrets — prompted during vars generation
    buildbot-github = {
      share = true;
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
      script = ''
        cat "$prompts"/app-secret-key > "$out"/app-secret-key
        cat "$prompts"/oauth-secret > "$out"/oauth-secret
      '';
    };
  };

  services.buildbot-nix.master = {
    enable = true;
    domain = "buildbot.decio.us";
    useHTTPS = true;
    buildSystems = [ "x86_64-linux" ];
    admins = [ "adeci" ];
    workersFile = config.clan.core.vars.generators.buildbot-workers.files."workers.json".path;
    github = {
      appId = 3002742;
      oauthId = "Iv23li39kVxcYTCXYahY";
      topic = "build-with-buildbot";
      appSecretKeyFile = config.clan.core.vars.generators.buildbot-github.files.app-secret-key.path;
      webhookSecretFile =
        config.clan.core.vars.generators.buildbot-webhook-secret.files.webhook-secret.path;
      oauthSecretFile = config.clan.core.vars.generators.buildbot-github.files.oauth-secret.path;
    };
  };

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.clan.core.vars.generators.buildbot-worker-leviathan.files.password.path;
    masterUrl = "tcp:host=localhost:port=9989";
    workers = 32;
  };
}

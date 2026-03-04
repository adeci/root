{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Workers that connect to this master. Add entries here when adding new workers.
  workers = {
    leviathan = {
      cores = 32;
    };
  };

  workerNames = lib.attrNames workers;
in
{
  imports = [
    inputs.buildbot-nix.nixosModules.buildbot-master
  ];

  # Per-worker passwords (shared with worker machines) and assembled workers.json
  clan.core.vars.generators =
    lib.mapAttrs' (
      name: _:
      lib.nameValuePair "buildbot-worker-${name}" {
        share = true;
        files.password = { };
        runtimeInputs = [ pkgs.pwgen ];
        script = ''
          pwgen -s 32 1 | tr -d '\n' > "$out"/password
        '';
      }
    ) workers
    // {
      buildbot-workers = {
        dependencies = map (name: "buildbot-worker-${name}") workerNames;
        files."workers.json" = { };
        runtimeInputs = [ pkgs.jq ];
        script = ''
          workers="[]"
        ''
        + lib.concatMapStrings (name: ''
          pass=$(cat "$in/buildbot-worker-${name}/password")
          workers=$(echo "$workers" | jq \
            --arg name "${name}" \
            --arg pass "$pass" \
            --argjson cores ${toString workers.${name}.cores} \
            '. + [{"name": $name, "pass": $pass, "cores": $cores}]')
        '') workerNames
        + ''
          echo "$workers" > "$out/workers.json"
        '';
      };

      # Webhook secret — auto-generated, paste into GitHub App form
      buildbot-webhook-secret = {
        share = true;
        files.webhook-secret = { };
        runtimeInputs = [ pkgs.openssl ];
        script = ''
          openssl rand -hex 32 | tr -d '\n' > "$out"/webhook-secret
        '';
      };

      # GitHub App secrets — prompted during vars generation (come from GitHub)
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
}

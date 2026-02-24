{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.adeci.buildbot-worker;
in
{
  options.adeci.buildbot-worker = {
    enable = lib.mkEnableOption "Buildbot CI worker (build executor)";

    masterHost = lib.mkOption {
      type = lib.types.str;
      default = "sequoia";
      description = "Tailscale hostname of the Buildbot master.";
    };

    workers = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = "Number of parallel build slots. 0 = auto-detect from core count.";
    };
  };

  imports = [
    inputs.buildbot-nix.nixosModules.buildbot-worker
  ];

  config = lib.mkIf cfg.enable {
    # Shared generator — same definition as in buildbot-master.nix.
    # Both machines declaring it become sops recipients for the secrets.
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

    services.buildbot-nix.worker = {
      enable = true;
      workerPasswordFile = config.clan.core.vars.generators.buildbot-workers.files.password.path;
      masterUrl = "tcp:host=${cfg.masterHost}:port=9989";
      inherit (cfg) workers;
    };
  };
}

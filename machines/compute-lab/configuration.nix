{
  config,
  pkgs,
  ...
}:
let
  canaryTokenPath = config.clan.core.vars.generators.compute-seed-canary.files.token.path;
in
{
  imports = [ ../../modules/microvms/guest-base.nix ];

  clan.core.vars.generators.compute-seed-canary = {
    files.token = { };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      openssl rand -hex 32 > "$out/token"
    '';
  };

  systemd.services.compute-seed-secret-canary = {
    description = "Verify seed-disk sops secret decryption";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-install-secrets.service" ];
    unitConfig.ConditionPathExists = canaryTokenPath;
    path = [ pkgs.coreutils ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      test -s ${canaryTokenPath}
      install -d -m 0755 /run/compute-seed-canary
      bytes=$(wc -c < ${canaryTokenPath})
      printf 'ok: decrypted %s bytes\n' "$bytes" > /run/compute-seed-canary/status
    '';
  };
}

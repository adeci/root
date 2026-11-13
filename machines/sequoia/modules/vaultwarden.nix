{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  domain = "vault.decio.us";
  inherit (self.inventory.cloudflare.tunnels.sequoia.${domain}) port;
  stateDirectory =
    if lib.versionOlder config.system.stateVersion "24.11" then "bitwarden_rs" else "vaultwarden";
  dataDir = "/var/lib/${stateDirectory}";
  backupDir = "/var/backup/vaultwarden";

  backup = pkgs.writeShellApplication {
    name = "vaultwarden-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.rsync
      pkgs.sqlite
    ];
    text = builtins.readFile ./vaultwarden-backup.sh;
  };

  restore = pkgs.writeShellApplication {
    name = "vaultwarden-restore";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.rsync
    ];
    text = builtins.readFile ./vaultwarden-restore.sh;
  };
  systemctl = lib.getExe' config.systemd.package "systemctl";
in
{
  clan.core.state.vaultwarden = {
    folders = [ backupDir ];
    preBackupScript = ''
      ${lib.getExe backup} ${dataDir} ${backupDir}
    '';
    preRestoreScript = ''
      ${systemctl} stop vaultwarden.service
    '';
    postRestoreScript = ''
      ${lib.getExe restore} ${backupDir} ${dataDir}
      ${systemctl} start vaultwarden.service
    '';
  };

  services.vaultwarden = {
    enable = true;
    environmentFile = config.clan.core.vars.generators.vaultwarden.files."vaultwarden.env".path;
    config = {
      DOMAIN = "https://${domain}";
      ROCKET_PORT = port;
      SIGNUPS_ALLOWED = false;
      INVITATIONS_ALLOWED = true;
      SHOW_PASSWORD_HINT = false;
      EXPERIMENTAL_CLIENT_FEATURE_FLAGS = "ssh-key-vault-item,ssh-agent";
    };
  };

  clan.core.vars.generators.vaultwarden = {
    files.admin_token_plaintext = {
      secret = true;
      deploy = false;
    };
    files."vaultwarden.env" = { };

    runtimeInputs = [
      pkgs.coreutils
      pkgs.pwgen
      pkgs.libargon2
    ];

    script = ''
      pwgen -s 48 1 | tr -d '\n' > "$out/admin_token_plaintext"

      SALT=$(pwgen -s 32 1 | tr -d '\n')
      HASHED=$(argon2 "$SALT" -e -id -k 65540 -t 3 -p 4 < "$out/admin_token_plaintext")

      echo "ADMIN_TOKEN='$HASHED'" > "$out/vaultwarden.env"
    '';
  };
}

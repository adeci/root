{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDirectory =
    if lib.versionOlder config.system.stateVersion "24.11" then "bitwarden_rs" else "vaultwarden";
  dataDir = "/var/lib/${stateDirectory}";
  backupDir = "/var/backup/vaultwarden";
in
{
  clan.core.state.vaultwarden = {
    folders = [ backupDir ];
    preBackupScript = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 -o vaultwarden -g vaultwarden ${backupDir}

      if [ ! -d ${dataDir} ]; then
        echo "No Vaultwarden data dir, skipping backup snapshot"
        exit 0
      fi

      if [ -f ${dataDir}/db.sqlite3 ]; then
        ${pkgs.sqlite}/bin/sqlite3 ${dataDir}/db.sqlite3 ".backup '${backupDir}/db.sqlite3'"
      fi
      ${pkgs.rsync}/bin/rsync -a --delete --exclude 'db.sqlite3*' ${dataDir}/ ${backupDir}/
      ${pkgs.coreutils}/bin/chown -R vaultwarden:vaultwarden ${backupDir}
    '';
    preRestoreScript = ''
      ${config.systemd.package}/bin/systemctl stop vaultwarden.service
    '';
    postRestoreScript = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 -o vaultwarden -g vaultwarden ${dataDir}
      ${pkgs.rsync}/bin/rsync -a --delete ${backupDir}/ ${dataDir}/
      ${pkgs.coreutils}/bin/chown -R vaultwarden:vaultwarden ${dataDir}
      ${config.systemd.package}/bin/systemctl start vaultwarden.service
    '';
  };

  services.vaultwarden = {
    enable = true;
    environmentFile = config.clan.core.vars.generators.vaultwarden.files."vaultwarden.env".path;
    config = {
      DOMAIN = "https://vault.decio.us";
      ROCKET_PORT = 8222;
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

    runtimeInputs = with pkgs; [
      coreutils
      pwgen
      libargon2
    ];

    script = ''
      pwgen -s 48 1 | tr -d '\n' > "$out/admin_token_plaintext"

      SALT=$(pwgen -s 32 1 | tr -d '\n')
      HASHED=$(argon2 "$SALT" -e -id -k 65540 -t 3 -p 4 < "$out/admin_token_plaintext")

      echo "ADMIN_TOKEN='$HASHED'" > "$out/vaultwarden.env"
    '';
  };
}

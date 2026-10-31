{
  config,
  inputs,
  pkgs,
  ...
}:
let
  vars = config.clan.core.vars.generators;
  hostname = "mandate.decio.us";
  backupDir = "/var/lib/mandate-backup";
in
{
  imports = [
    inputs.mandate.nixosModules.default
    ../../../modules/nixos/acme.nix
  ];

  clan.core.vars.generators.mandate = {
    files.token = { };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      openssl rand -hex 32 > "$out"/token
    '';
  };

  clan.core.vars.generators.mandate-console = {
    files.admin_password_plaintext = {
      secret = true;
      deploy = false;
    };
    files.admin_password_hash = { };

    runtimeInputs = with pkgs; [
      coreutils
      pwgen
      mkpasswd
    ];

    script = ''
      pwgen -s 48 1 | tr -d '\n' > "$out/admin_password_plaintext"
      mkpasswd -m bcrypt -R 12 -s < "$out/admin_password_plaintext" | tr -d '\n' > "$out/admin_password_hash"
    '';
  };

  services.mandate = {
    enable = true;
    inherit hostname;
    useACMEHost = hostname;
    tokenFile = vars.mandate.files.token.path;
    adminPasswordHashFile = vars.mandate-console.files.admin_password_hash.path;
    connectors = {
      whatsapp = { };
      discord = { };
    };
  };

  # Consistent snapshots of the message databases, the console's proposals and
  # keys, and exposure.toml; not the sessions in private/.
  clan.core.state.mandate = {
    folders = [ backupDir ];
    preBackupScript = # bash
      ''
        ${pkgs.coreutils}/bin/install -d -m 0700 ${backupDir}
        for db in /var/lib/mandate-*/data.db /var/lib/mandate-console/console.db; do
          if [ -f "$db" ]; then
            ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup ${backupDir}/$(basename "$(dirname "$db")").db"
          fi
        done
        for f in /var/lib/mandate-console/keys.json /var/lib/mandate-gateway/exposure.toml; do
          if [ -f "$f" ]; then
            ${pkgs.coreutils}/bin/cp "$f" ${backupDir}/
          fi
        done
      '';
  };
}

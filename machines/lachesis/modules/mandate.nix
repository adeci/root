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
    ../../../modules/nixos/mandate-ntfy.nix
  ];

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
    notify.ntfy = {
      url = "http://sequoia.cymric-daggertooth.ts.net:2586/mandate";
      tokenFile = vars.mandate-ntfy.files.token.path;
    };
    adminPasswordHashFile = vars.mandate-console.files.admin_password_hash.path;
    connectors = {
      whatsapp = { };
      discord = { };
      signal = { };
      matrix = { };
      gmessages = { };
      fastmail = { };
    };
  };

  # Consistent snapshots of the message databases, the console's proposals,
  # agents and keys, the gateway's key log and remembered revocations, and
  # exposure.toml; not the sessions in private/. Media references are dropped
  # from the copies: some hold per-file keys that fetch from the services'
  # CDNs without the account.
  clan.core.state.mandate = {
    folders = [ backupDir ];
    preBackupScript = # bash
      ''
        umask 0077
        ${pkgs.coreutils}/bin/install -d -m 0700 ${backupDir}
        ${pkgs.coreutils}/bin/rm -f ${backupDir}/*
        for db in /var/lib/mandate-*/data.db /var/lib/mandate-console/console.db; do
          if [ -f "$db" ]; then
            out=${backupDir}/$(basename "$(dirname "$db")").db
            ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup $out"
            if [ -n "$(${pkgs.sqlite}/bin/sqlite3 "$out" "SELECT 1 FROM sqlite_master WHERE name = 'media'")" ]; then
              ${pkgs.sqlite}/bin/sqlite3 "$out" "UPDATE media SET ref = NULL; VACUUM;"
            fi
          fi
        done
        for f in /var/lib/mandate-console/keys.json /var/lib/mandate-gateway/{exposure.toml,keys.json,access.json}; do
          if [ -f "$f" ]; then
            ${pkgs.coreutils}/bin/cp "$f" ${backupDir}/$(basename "$(dirname "$f")")-$(basename "$f")
          fi
        done
      '';
  };
}

{
  config,
  inputs,
  pkgs,
  ...
}:
let
  vars = config.clan.core.vars.generators;
  hostname = "mandate.decio.us";
  certDir = config.security.acme.certs.${hostname}.directory;
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

  services.mandate = {
    enable = true;
    tokenFile = vars.mandate.files.token.path;
    connectors.whatsapp = { };
    console = {
      enable = true;
      inherit hostname;
      tlsCertFile = "${certDir}/fullchain.pem";
      tlsKeyFile = "${certDir}/key.pem";
    };
  };

  # The console copies the cert in at start, so a renewal needs a restart.
  security.acme.certs.${hostname}.reloadServices = [ "mandate-console.service" ];
  systemd.services.mandate-console = {
    wants = [ "acme-${hostname}.service" ];
    after = [ "acme-${hostname}.service" ];
  };

  # Back up consistent snapshots of the message database, the console's
  # decided proposals, and exposure.toml, never the session state in private/.
  clan.core.state.mandate = {
    folders = [ backupDir ];
    preBackupScript = # bash
      ''
        ${pkgs.coreutils}/bin/install -d -m 0700 ${backupDir}
        for db in /var/lib/mandate-whatsapp/data.db /var/lib/mandate-console/console.db; do
          if [ -f "$db" ]; then
            ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup ${backupDir}/$(basename "$(dirname "$db")").db"
          fi
        done
        if [ -f /var/lib/mandate-gateway/exposure.toml ]; then
          ${pkgs.coreutils}/bin/cp /var/lib/mandate-gateway/exposure.toml ${backupDir}/
        fi
      '';
  };
}

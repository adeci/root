{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  domain = "mandate.decio.us";
  certDir = config.security.acme.certs.${domain}.directory;
  connectors = [
    "whatsapp"
    "discord"
    "signal"
    "matrix"
    "gmessages"
    "fastmail"
  ];
  state = "/var/lib/private/mandate";
  backupDir = "/var/lib/mandate-backup";
in
{
  imports = [
    inputs.mandate.nixosModules.default
    ../../../modules/nixos/acme.nix
  ];

  security.acme.certs.${domain} = {
    group = "mandate-front";
    reloadServices = [ "mandate-front.service" ];
  };

  services.mandate = {
    enable = true;
    listen = ":443";
    agentListen = ":8443";
    tls = {
      mode = "cert";
      cert = "${certDir}/fullchain.pem";
      key = "${certDir}/key.pem";
    };
    connectors = lib.genAttrs connectors (_: { });
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    443
    8443
  ];

  # Snapshots of the stores, the owner side's state and the gateway's live
  # set, never the sessions in private/. Media refs are dropped from the
  # copies: some carry keys that fetch from the services' CDNs on their own.
  clan.core.state.mandate = {
    folders = [ backupDir ];
    preBackupScript = # bash
      ''
        umask 0077
        ${pkgs.coreutils}/bin/install -d -m 0700 ${backupDir}
        ${pkgs.coreutils}/bin/rm -rf ${backupDir}/*
        for db in ${state}/connectors/*/data.db; do
          if [ -f "$db" ]; then
            out=${backupDir}/$(basename "$(dirname "$db")").db
            ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup $out"
            if [ -n "$(${pkgs.sqlite}/bin/sqlite3 "$out" "SELECT 1 FROM sqlite_master WHERE name = 'media'")" ]; then
              ${pkgs.sqlite}/bin/sqlite3 "$out" "UPDATE media SET ref = NULL; VACUUM;"
            fi
          fi
        done
        if [ -d ${state}/owner ]; then ${pkgs.coreutils}/bin/cp -r ${state}/owner ${backupDir}/owner; fi
        if [ -f ${state}/gateway/live.json ]; then ${pkgs.coreutils}/bin/cp ${state}/gateway/live.json ${backupDir}/gateway-live.json; fi
      '';
  };
}

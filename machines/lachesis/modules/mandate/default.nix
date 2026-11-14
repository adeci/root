{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  domain = "mandate.decio.us";
  certificateDirectory = config.security.acme.certs.${domain}.directory;
  connectors = [
    "whatsapp"
    "discord"
    "signal"
    "matrix"
    "gmessages"
    "fastmail"
  ];
  backupDirectory = "/var/lib/mandate-backup";

  preBackup = pkgs.writeShellApplication {
    name = "mandate-pre-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.sqlite
    ];
    runtimeEnv = {
      STATE_DIRECTORY = "/var/lib/private/mandate";
      BACKUP_DIRECTORY = backupDirectory;
    };
    text = builtins.readFile ./mandate-pre-backup.sh;
  };
in
{
  imports = [
    inputs.mandate.nixosModules.default
    self.modules.nixos.acme
  ];

  acme.tokenGenerator = self.inventory.cloudflare.acmeTokenGenerator;

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
      cert = "${certificateDirectory}/fullchain.pem";
      key = "${certificateDirectory}/key.pem";
    };
    connectors = lib.genAttrs connectors (_: { });
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    443
    8443
  ];

  # Snapshots stores, owner state and gateway live set, not sessions.
  clan.core.state.mandate = {
    folders = [ backupDirectory ];
    # clan-core makes this text the body of its pre-backup-mandate script.
    preBackupScript = lib.getExe preBackup;
  };
}

# Runs cloudflared in connector mode when this machine has a tunnel
# defined in inventory/tunnels.nix. The tunnel token is provided by
# terraform via clan vars.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  tunnels = import ../../inventory/tunnels.nix;
  machineName = config.networking.hostName;
  hasTunnel = tunnels ? ${machineName};
  tokenPath = config.clan.core.vars.generators.cloudflare-tunnel-token.files.token.path;
in
{
  config = lib.mkIf hasTunnel {
    systemd.services."cloudflared-tunnel-${machineName}" = {
      description = "Cloudflare Tunnel ${machineName}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      script = ''
        ${lib.getExe pkgs.cloudflared} tunnel --no-autoupdate run \
          --token "$(cat "$CREDENTIALS_DIRECTORY/token")"
      '';

      serviceConfig = {
        LoadCredential = [ "token:${tokenPath}" ];
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
      };
    };

    clan.core.vars.generators.cloudflare-tunnel-token = {
      files.token = {
        secret = true;
      };
    };
  };
}

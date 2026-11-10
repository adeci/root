{
  nixos =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      inherit (self.resources.cloudflare) tunnels;
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

          script = # bash
            ''
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

        # Terraform writes the token with `clan vars set`.
        clan.core.vars.generators.cloudflare-tunnel-token = {
          files.token = {
            secret = true;
            restartUnits = [ "cloudflared-tunnel-${machineName}.service" ];
          };
        };
      };
    };
}

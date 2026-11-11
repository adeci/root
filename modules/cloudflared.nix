{
  nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.cloudflared) token;
      machineName = config.networking.hostName;
      tokenPath = config.clan.core.vars.generators.${token.generator}.files.${token.file}.path;
    in
    {
      options.cloudflared.token = lib.mkOption {
        description = "Clan var holding this machine's tunnel token.";
        type = lib.types.submodule {
          options = {
            generator = lib.mkOption { type = lib.types.str; };
            file = lib.mkOption { type = lib.types.str; };
          };
        };
      };

      config = {
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

        # The token is provisioned externally with `clan vars set`.
        clan.core.vars.generators.${token.generator} = {
          files.${token.file} = {
            secret = true;
            restartUnits = [ "cloudflared-tunnel-${machineName}.service" ];
          };
        };
      };
    };
}

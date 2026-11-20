{
  _class = "clan.service";

  manifest = {
    name = "@adeci/tailscale";
    description = "Thin Clan auth-key glue for Tailscale on NixOS and nix-darwin";
    categories = [ "Utility" ];
    readme = builtins.readFile ./README.md;
  };

  roles.peer = {
    description = "Tailscale peer enrolled with a Clan-managed auth key";
    interface =
      { lib, ... }:
      {
        options = {
          flags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "--accept-dns=false" ];
            description = "Tailscale preferences applied to every peer in this instance on NixOS and nix-darwin.";
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      let
        generatorName = "tailscale-${instanceName}";
        shared =
          { pkgs, ... }:
          {
            clan.core.vars.generators.${generatorName} = {
              share = true;
              files.auth_key = { };
              runtimeInputs = [ pkgs.coreutils ];
              prompts.auth_key = {
                description = "Tailscale auth key for instance '${instanceName}'";
                type = "hidden";
                persist = true;
              };
              script = # bash
                ''
                  cat "$prompts"/auth_key > "$out"/auth_key
                '';
            };
          };
      in
      {
        nixosModule =
          { config, lib, ... }:
          {
            imports = [ shared ];
            services.tailscale = {
              enable = true;
              authKeyFile = config.clan.core.vars.generators.${generatorName}.files.auth_key.path;
              extraUpFlags = settings.flags;
              # First in the list, so a machine's own flags follow and win.
              extraSetFlags = lib.mkBefore ([ "--accept-routes=false" ] ++ settings.flags);
            };
            # Tailscale's netfilter rule accepts tailscale0 first; the tailnet policy filters it.
            networking.firewall.trustedInterfaces = [ config.services.tailscale.interfaceName ];
            # RemainAfterExit, so a deploy that changes the flags restarts it.
            systemd.services.tailscaled-set = lib.mkIf (config.services.tailscale.extraSetFlags != [ ]) {
              serviceConfig.RemainAfterExit = true;
            };
          };
        darwinModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            connect = pkgs.writeShellApplication {
              name = "tailscale-connect";
              runtimeInputs = [
                config.services.tailscale.package
                pkgs.jq
              ];
              text = builtins.readFile ./connect.sh;
            };
          in
          {
            imports = [ shared ];
            services.tailscale.enable = true;
            launchd.daemons.tailscale-connect.serviceConfig = {
              ProgramArguments = [
                (lib.getExe connect)
                config.clan.core.vars.generators.${generatorName}.files.auth_key.path
                "--accept-routes=false"
              ]
              ++ settings.flags;
              RunAtLoad = true;
              KeepAlive.SuccessfulExit = false;
              ThrottleInterval = 30;
            };
          };
      };
  };
}

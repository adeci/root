_: {
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
          auth-key-generator = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Clan vars generator containing the Tailscale auth key. Defaults to tailscale-<instance>.";
          };
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
        generatorName =
          if settings.auth-key-generator != null then
            settings.auth-key-generator
          else
            "tailscale-${instanceName}";
        varsModule =
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
            imports = [ varsModule ];
            services.tailscale = {
              enable = true;
              authKeyFile = config.clan.core.vars.generators.${generatorName}.files.auth_key.path;
              extraUpFlags = settings.flags;
              extraSetFlags = lib.mkDefault ([ "--accept-routes=false" ] ++ settings.flags);
            };
          };
        darwinModule =
          { config, lib, ... }:
          {
            imports = [ varsModule ];
            services.tailscale.enable = true;
            launchd.daemons.tailscale-connect.serviceConfig = {
              ProgramArguments = [
                (lib.getExe config.services.tailscale.package)
                "up"
                "--auth-key=file:${config.clan.core.vars.generators.${generatorName}.files.auth_key.path}"
                "--accept-routes=false"
                "--timeout=30s"
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

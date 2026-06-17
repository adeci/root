_: {
  _class = "clan.service";

  manifest = {
    name = "@adeci/tailscale";
    description = "Thin Clan auth-key glue for the upstream Tailscale NixOS module";
    categories = [ "Utility" ];
    readme = builtins.readFile ./README.md;
  };

  roles.peer = {
    description = "Tailscale peer enrolled with a Clan-managed auth key";
    interface =
      { lib, ... }:
      {
        options.auth-key-generator = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Clan vars generator containing the Tailscale auth key. Defaults to tailscale-<instance>.";
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            generatorName =
              if settings.auth-key-generator != null then
                settings.auth-key-generator
              else
                "tailscale-${instanceName}";
          in
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

            services.tailscale = {
              enable = true;
              authKeyFile = config.clan.core.vars.generators.${generatorName}.files.auth_key.path;
              extraSetFlags = lib.mkDefault [ "--accept-routes=false" ];
            };
          };
      };
  };
}

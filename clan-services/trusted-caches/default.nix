_: {
  _class = "clan.service";

  manifest = {
    name = "@adeci/trusted-caches";
    description = "Configure trusted binary cache substituters";
    categories = [ "System" ];
    readme = builtins.readFile ./README.md;
  };

  roles.default = {
    description = "Configures nix to trust and use the specified binary caches";

    interface =
      { lib, ... }:
      {
        options.caches = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                url = lib.mkOption {
                  type = lib.types.str;
                  description = "URL of the binary cache";
                  example = "https://cache.numtide.com";
                };
                publicKey = lib.mkOption {
                  type = lib.types.str;
                  description = "Public signing key for the binary cache";
                  example = "cache.example.com-1:AAAA...";
                };
                priority = lib.mkOption {
                  type = lib.types.int;
                  default = 50;
                  description = "Substituter priority (lower = higher priority)";
                };
              };
            }
          );
          default = [ ];
          description = "List of trusted binary caches to configure";
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule = _: {
          nix.settings.substituters = map (
            cache: "${cache.url}?priority=${toString cache.priority}"
          ) settings.caches;

          nix.settings.trusted-public-keys = map (cache: cache.publicKey) settings.caches;
        };
      };
  };
}

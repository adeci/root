let
  profiles =
    { config, lib, ... }:
    {
      options.system = {
        userProfiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          default = { };
          description = "User registry entries of the machine's accounts, by username.";
        };
        primaryUserProfile = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          description = "User registry entry of the primary user.";
        };
      };

      config.system.primaryUserProfile = config.system.userProfiles.${config.system.primaryUser};
    };
in
{
  # nix-darwin already has system.primaryUser.
  nixos =
    { lib, ... }:
    {
      imports = [ profiles ];

      options.system.primaryUser = lib.mkOption {
        type = lib.types.str;
        description = "Name of the machine's main interactive user.";
      };
    };

  darwin = profiles;
}

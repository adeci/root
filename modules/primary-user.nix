let
  shared =
    { config, lib, ... }:
    {
      options.system = {
        userProfiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.raw;
          default = { };
          description = "Profiles of the machine's accounts, by user name.";
        };
        primaryUserProfile = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          description = "Profile of the primary user.";
        };
      };

      config.system.primaryUserProfile = config.system.userProfiles.${config.system.primaryUser};
    };
in
{
  # nix-darwin already has system.primaryUser and system.primaryUserHome.
  nixos =
    { config, lib, ... }:
    {
      imports = [ shared ];

      options.system = {
        primaryUser = lib.mkOption {
          type = lib.types.str;
          description = "Name of the machine's main interactive user.";
        };
        primaryUserHome = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          description = "Home directory of the primary user.";
        };
      };

      config.system.primaryUserHome = config.users.users.${config.system.primaryUser}.home;
    };

  darwin =
    { config, lib, ... }:
    let
      user = config.system.primaryUser;
    in
    {
      imports = [ shared ];

      options.system.asPrimaryUser = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Prefix that runs an activation-script command as the primary user, inside their login session.";
      };

      config.system.asPrimaryUser = ''launchctl asuser "$(/usr/bin/id -u -- ${user})" sudo -H --user=${user} --'';
    };
}

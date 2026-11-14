{ config, lib, ... }:
let
  inherit (import ../lib.nix { inherit lib; }) nixEntries;
  inherit (config.flake) modules;

  # One password per profile on every machine: asked for, or four random words.
  passwordModule =
    name: user:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      generator = "user-password-${name}";
    in
    {
      users.users.${user}.hashedPasswordFile =
        config.clan.core.vars.generators.${generator}.files.user-password-hash.path;

      clan.core.vars.generators.${generator} = {
        share = true;
        files.user-password-hash = {
          neededFor = "users";
          restartUnits = lib.optional config.services.userborn.enable "userborn.service";
        };
        files.user-password.deploy = false;
        prompts.user-password = {
          display = {
            group = name;
            label = "password";
            required = false;
            helperText = "Leave empty to auto-generate a secure password";
          };
          type = "hidden";
          persist = true;
          description = "Password for user ${name}";
        };
        runtimeInputs = [
          pkgs.coreutils
          pkgs.xkcdpass
          pkgs.mkpasswd
        ];
        script = builtins.readFile ./user-password.sh;
      };
    };

  profileType = lib.types.submodule (
    { name, config, ... }:
    let
      profile = config;
      user = profile.username;
    in
    {
      options = {
        username = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Account name; profiles of one person can share it.";
        };
        description = lib.mkOption {
          type = lib.types.str;
          description = "Full name of the account.";
        };
        uid = lib.mkOption {
          type = lib.types.int;
          description = "uid on NixOS; macOS assigns its own.";
        };
        shell = lib.mkOption {
          type = lib.types.enum [
            "bash"
            "zsh"
          ];
          default = "bash";
          description = "Login shell where no feature sets one.";
        };
        groups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra groups on NixOS.";
        };
        sshKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "Public keys that log in as the account, each ending in a comment that names it.";
        };
        email = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Email address of the person.";
        };
        git = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                name = lib.mkOption { type = lib.types.str; };
                email = lib.mkOption { type = lib.types.str; };
              };
            }
          );
          default = null;
          description = "Commit identity.";
        };
        timeZone = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Time zone of the machines this profile is the primary user of, unless they track their location.";
        };
        keyNamed = lib.mkOption {
          type = lib.types.functionTo lib.types.str;
          readOnly = true;
          description = "The SSH key with this comment; picking by comment survives reordering sshKeys.";
        };
        nixosModule = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          description = "Creates the account on NixOS and makes it the primary user unless the machine picks another.";
        };
        darwinModule = lib.mkOption {
          type = lib.types.raw;
          readOnly = true;
          description = "Creates the account on macOS and makes it the primary user.";
        };
      };

      config = {
        keyNamed =
          comment:
          lib.findFirst (lib.hasSuffix " ${
             comment
           }") (throw "profile ${name} has no SSH key named ${comment}") profile.sshKeys;

        nixosModule =
          { lib, pkgs, ... }:
          {
            imports = [
              modules.nixos.primary-user
              (passwordModule name user)
            ];

            system.primaryUser = lib.mkDefault user;
            system.userProfiles.${user} = profile;

            users.users.${user} = {
              inherit (profile) uid description;
              isNormalUser = true;
              shell = lib.mkIf (profile.shell != "bash") (lib.mkDefault pkgs.${profile.shell});
              extraGroups = profile.groups;
              openssh.authorizedKeys.keys = profile.sshKeys;
            };
          };

        darwinModule = {
          imports = [ modules.darwin.primary-user ];

          system.primaryUser = lib.mkDefault user;
          system.userProfiles.${user} = profile;

          # nix-darwin owns the account, so users.users sets its login shell and keys without dscl.
          users.knownUsers = [ user ];
          users.users.${user} = {
            # macOS gives the first account 501.
            uid = lib.mkDefault 501;
            inherit (profile) description;
            home = "/Users/${user}";
            openssh.authorizedKeys.keys = profile.sshKeys;
          };
        };
      };
    }
  );
in
{
  options.flake.users = lib.mkOption {
    type = lib.types.attrsOf profileType;
    default = { };
    description = "User profiles from inventory/users, by file name; a machine imports a profile's nixosModule or darwinModule to get the account.";
  };

  config.flake.users = lib.mapAttrs (_: import) (nixEntries ../../inventory/users);
}

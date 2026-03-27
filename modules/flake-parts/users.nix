# User definitions available flake-wide via self.users.*
#
# Each user gets:
#   self.users.<name>.sshKeys / .uid / .username / etc. — pure data
#   self.users.<name>.nixosModule — import this to create the user on a NixOS machine
#   self.users.<name>.darwinModule — import this to create the user on a Darwin machine
#
# User data lives in inventory/users/. This module wraps it with mkUser.
{ lib, ... }:
let
  rawUsers = import ../../inventory/users;

  mkUser =
    name: attrs:
    attrs
    // {
      username = name;

      nixosModule =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          users.users.${name} = {
            inherit (attrs) uid description;
            isNormalUser = true;
            createHome = true;
            home = "/home/${name}";
            shell = pkgs.${attrs.shell};
            extraGroups = attrs.groups;
            openssh.authorizedKeys.keys = attrs.sshKeys;
            hashedPasswordFile =
              config.clan.core.vars.generators."user-password-${name}".files.user-password-hash.path;
          };

          clan.core.vars.generators."user-password-${name}" = {
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

            share = true;

            runtimeInputs = [
              pkgs.coreutils
              pkgs.xkcdpass
              pkgs.mkpasswd
            ];

            script = ''
              prompt_value=$(cat "$prompts"/user-password)
              if [[ -n "''${prompt_value-}" ]]; then
                echo "$prompt_value" | tr -d "\n" > "$out"/user-password
              else
                xkcdpass --numwords 4 --delimiter - --count 1 | tr -d "\n" > "$out"/user-password
              fi
              mkpasswd -s -m sha-512 < "$out"/user-password | tr -d "\n" > "$out"/user-password-hash
            '';
          };
        };

      darwinModule = _: {
        users.users.${name} = {
          inherit name;
          inherit (attrs) uid description;
          home = "/Users/${name}";
          openssh.authorizedKeys.keys = attrs.sshKeys;
        };
      };
    };
in
{
  options.flake.users = lib.mkOption { default = { }; };

  config.flake.users = lib.mapAttrs mkUser rawUsers;
}

let
  shared =
    { config, lib, ... }:
    {
      options.home.links = lib.mkOption {
        type = lib.types.attrsOf lib.types.pathInStore;
        default = { };
        example = lib.literalExpression ''{ ".config/foo/config.toml" = fooConfig; }'';
        description = "Store paths to link into the primary user's home, by relative path. A real file in the way stops the switch. Dropped entries are removed at the next switch, with folders left empty, unless the link was replaced or repointed.";
      };

      # . or .. could dodge the real-file check or walk the cleanup out of the home.
      config.assertions = lib.mapAttrsToList (path: _: {
        assertion = !lib.any (part: part == "" || part == "." || part == "..") (lib.splitString "/" path);
        message = "home.links.\"${path}\": keys must be relative to the home, with no empty, . or .. parts.";
      }) config.home.links;
    };

  # Table lines are "link<TAB>target".
  homeLinks =
    {
      config,
      lib,
      pkgs,
    }:
    {
      command = lib.getExe (pkgs.callPackage ./package.nix { });
      table = pkgs.writeText "home-links" (
        lib.concatStrings (
          lib.mapAttrsToList (
            path: target: "${config.system.primaryUserHome}/${path}\t${target}\n"
          ) config.home.links
        )
      );
    };
in
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
      inherit (homeLinks { inherit config lib pkgs; }) command table;
    in
    {
      imports = [
        self.modules.nixos.primary-user
        shared
      ];

      system.preSwitchChecks.home-links = "${command} --check ${table}";

      systemd.services.home-links = {
        description = "Links into ${config.system.primaryUser}'s home";
        wantedBy = [ "multi-user.target" ];
        before = [ "systemd-user-sessions.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = config.system.primaryUser;
          StateDirectory = "home-links";
          ExecStart = "${command} ${table}";
        };
      };
    };

  darwin =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      inherit (homeLinks { inherit config lib pkgs; }) command table;
    in
    {
      imports = [
        self.modules.darwin.primary-user
        shared
      ];

      system.activationScripts.preActivation.text = ''
        ${command} --check ${table}
      '';
      system.activationScripts.postActivation.text = ''
        # nix-darwin has no StateDirectory.
        mkdir -p /var/lib/home-links
        chown ${config.system.primaryUser} /var/lib/home-links
        # Not asPrimaryUser: a headless Mac has no login session after reboot.
        /usr/bin/sudo -H -u ${config.system.primaryUser} -- /usr/bin/env STATE_DIRECTORY=/var/lib/home-links ${command} ${table}
      '';
    };
}

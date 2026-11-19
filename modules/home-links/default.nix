let
  shared =
    { config, lib, ... }:
    {
      options.home.links = lib.mkOption {
        type = lib.types.attrsOf lib.types.pathInStore;
        default = { };
        example = lib.literalExpression ''{ ".config/foo/config.toml" = fooConfig; }'';
        description = "Store paths to link into the primary user's home, keyed by path relative to it. A real file in a link's place stops the switch. A link whose entry goes away is removed at the next switch, with the folders that leaves empty, unless it has been replaced or pointed elsewhere.";
      };

      # A . or .. part could slip a link past the real-file check, or the empty-folder walk out of the home.
      config.assertions = lib.mapAttrsToList (path: _: {
        assertion = !lib.any (part: part == "" || part == "." || part == "..") (lib.splitString "/" path);
        message = "home.links.\"${path}\" is not a path inside the home: keys are relative, with no empty, . or .. part.";
      }) config.home.links;
    };

  # The command that makes the links and removes those of dropped entries, and the table it reads: one "link<TAB>target" line per entry.
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
        # nix-darwin has no StateDirectory: the user's run keeps its record in a /var/lib folder made for it here.
        mkdir -p /var/lib/home-links
        chown ${config.system.primaryUser} /var/lib/home-links
        # Not asPrimaryUser: its launchctl asuser needs a login session, which a headless Mac lacks after a reboot.
        /usr/bin/sudo -H -u ${config.system.primaryUser} -- /usr/bin/env STATE_DIRECTORY=/var/lib/home-links ${command} ${table}
      '';
    };
}

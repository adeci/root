let
  shared =
    { lib, ... }:
    {
      # Stale links stay behind when an entry goes away.
      options.home.links = lib.mkOption {
        type = lib.types.attrsOf lib.types.pathInStore;
        default = { };
        example = lib.literalExpression ''{ ".config/foo/config.toml" = fooConfig; }'';
        description = "Store paths to link into the primary user's home, keyed by path relative to it. A real file in a link's place stops the switch.";
      };
    };

  # The command that makes the links, and the table it reads: one "link<TAB>target" line per entry.
  homeLinks =
    {
      config,
      lib,
      pkgs,
    }:
    {
      command = lib.getExe (
        pkgs.writeShellApplication {
          name = "home-links";
          runtimeInputs = [ pkgs.coreutils ];
          text = builtins.readFile ./link.sh;
        }
      );
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

      config = lib.mkIf (config.home.links != { }) {
        system.preSwitchChecks.home-links = "${command} --check ${table}";

        systemd.services.home-links = {
          description = "Links into ${config.system.primaryUser}'s home";
          wantedBy = [ "multi-user.target" ];
          before = [ "systemd-user-sessions.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = config.system.primaryUser;
            ExecStart = "${command} ${table}";
          };
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

      config = lib.mkIf (config.home.links != { }) {
        system.activationScripts.preActivation.text = ''
          ${command} --check ${table}
        '';
        system.activationScripts.postActivation.text = ''
          /usr/bin/sudo -u ${config.system.primaryUser} -- ${command} ${table}
        '';
      };
    };
}

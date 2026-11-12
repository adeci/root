{
  # One-time System Settings steps macOS only takes from a person; features declare them and the installer walks through /etc/mac-setup.json.
  darwin =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      user = config.system.primaryUser;
      tccDb = {
        system = "/Library/Application Support/com.apple.TCC/TCC.db";
        user = "${config.users.users.${user}.home}/Library/Application Support/com.apple.TCC/TCC.db";
      };

      grantCheck =
        grant:
        "/usr/bin/sqlite3 ${lib.escapeShellArg tccDb.${grant.scope}} "
        + lib.escapeShellArg "select auth_value from access where service = '${grant.service}' and client = '${grant.client}'"
        + " 2>/dev/null | /usr/bin/grep -qx 2";

      step = types.submodule {
        options = {
          name = mkOption { type = types.str; };
          url = mkOption {
            type = types.str;
            description = "System Settings deep link opened on the Mac.";
          };
          instructions = mkOption { type = types.str; };
          grants = mkOption {
            type = types.listOf (
              types.submodule {
                options = {
                  service = mkOption {
                    type = types.str;
                    example = "kTCCServiceAccessibility";
                  };
                  client = mkOption {
                    type = types.str;
                    description = "Bundle id, or the executable's path for bare binaries.";
                  };
                  scope = mkOption {
                    type = types.enum [
                      "system"
                      "user"
                    ];
                    default = "system";
                    description = "Which TCC database records it; Microphone and Camera are per user.";
                  };
                };
              }
            );
            default = [ ];
            description = "Privacy grants that mark the step done.";
          };
          check = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Shell run as root on the Mac that succeeds once the step is done; replaces the grants check.";
          };
          restart = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "gui/org.nixos.aerospace" ];
            description = "launchd services restarted afterwards: gui/<label> in the user's session, system/<label> otherwise.";
          };
        };
      };
    in
    {
      options.macSetup.steps = mkOption {
        type = types.listOf step;
        default = [ ];
        description = "Manual System Settings steps, in order.";
      };

      config = {
        environment.etc."mac-setup.json".text = builtins.toJSON {
          inherit user;
          inherit (config.users.users.${user}) uid;
          steps = map (s: {
            inherit (s)
              name
              url
              instructions
              restart
              ;
            check =
              if s.check != null then
                s.check
              else if s.grants != [ ] then
                lib.concatMapStringsSep " && " grantCheck s.grants
              else
                null;
          }) config.macSetup.steps;
        };
      };
    };
}

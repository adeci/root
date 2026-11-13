{
  # System Settings steps only a person can take.
  darwin =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      user = config.system.primaryUser;
      tccDatabase = {
        system = "/Library/Application Support/com.apple.TCC/TCC.db";
        user = "${config.system.primaryUserHome}/Library/Application Support/com.apple.TCC/TCC.db";
      };

      grantCheck =
        grant:
        "/usr/bin/sqlite3 ${lib.escapeShellArg tccDatabase.${grant.scope}} "
        + lib.escapeShellArg "select auth_value from access where service = '${grant.service}' and client = '${grant.client}'"
        + " 2>/dev/null | /usr/bin/grep -qx 2";

      stepType = lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          url = lib.mkOption {
            type = lib.types.str;
            description = "System Settings deep link opened on the Mac.";
          };
          instructions = lib.mkOption { type = lib.types.str; };
          grants = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  service = lib.mkOption {
                    type = lib.types.str;
                    example = "kTCCServiceAccessibility";
                  };
                  client = lib.mkOption {
                    type = lib.types.str;
                    description = "Bundle id, or the executable's path for bare binaries.";
                  };
                  scope = lib.mkOption {
                    type = lib.types.enum [
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
          check = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Shell run as root on the Mac that succeeds once the step is done; replaces the grants check.";
          };
          restart = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [ "gui/org.nixos.aerospace" ];
            description = "launchd services restarted afterwards: gui/<label> in the user's session, system/<label> otherwise.";
          };
        };
      };
    in
    {
      imports = [ self.modules.darwin.primary-user ];

      options.macSetup.steps = lib.mkOption {
        type = lib.types.listOf stepType;
        default = [ ];
        description = "Manual System Settings steps, in order; mac-install walks them through /etc/mac-setup.json.";
      };

      config = {
        environment.etc."mac-setup.json".text = builtins.toJSON {
          inherit user;
          inherit (config.users.users.${user}) uid;
          steps = map (step: {
            inherit (step)
              name
              url
              instructions
              restart
              ;
            check =
              if step.check != null then
                step.check
              else if step.grants != [ ] then
                lib.concatMapStringsSep " && " grantCheck step.grants
              else
                null;
          }) config.macSetup.steps;
        };
      };
    };
}

{
  lib,
  pkgs,
  config,
  machine,
  isDarwin,
  resolved,
}:
[
  {
    assertions = [
      {
        assertion = resolved.undefinedUsers == [ ];
        message = "Roster: Users referenced in machine '${machine.name}' but not defined: ${builtins.concatStringsSep ", " resolved.undefinedUsers}";
      }
      {
        assertion = resolved.invalidPositions == [ ];
        message = "Roster: Unknown positions used in machine '${machine.name}': ${builtins.concatStringsSep ", " resolved.invalidPositions}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames resolved.allPositions)}";
      }
    ];
  }

  {
    users.users = lib.mapAttrs (
      username: cfg:
      lib.mkMerge [
        (
          if isDarwin then
            {
              name = username;
              uid = cfg.effectiveUid;
              home = cfg.homeDir;
              inherit (cfg.userDef) description;
              openssh.authorizedKeys.keys = cfg.effectiveSshKeys;
            }
          else
            {
              uid = cfg.effectiveUid;
              inherit (cfg.userDef) description;
              inherit (cfg.effectiveFlags) isSystemUser;
              isNormalUser = !cfg.effectiveFlags.isSystemUser;
              createHome = cfg.effectiveFlags.homeDirectory;
              home = if cfg.effectiveFlags.homeDirectory then cfg.homeDir else "/var/empty";
              group = if cfg.effectiveFlags.isSystemUser then username else "users";
              extraGroups = cfg.effectiveGroups ++ (lib.optional cfg.effectiveFlags.sudoAccess "wheel");
              openssh.authorizedKeys.keys = cfg.effectiveSshKeys;
            }
        )

        (lib.mkIf (cfg.effectiveShell != null) {
          shell = cfg.effectiveShell;
        })
      ]
    ) resolved.allUserConfigs;
  }

  (lib.mkIf (!isDarwin) {
    users.users.root.openssh.authorizedKeys.keys = resolved.rootSshKeys;
  })

  (lib.mkIf (!isDarwin) {
    users.groups = lib.mapAttrs' (username: _: lib.nameValuePair username { }) (
      lib.filterAttrs (_: cfg: cfg.effectiveFlags.isSystemUser) resolved.allUserConfigs
    );
  })

  (lib.mkIf (!isDarwin) {
    clan.core.vars.generators = lib.mapAttrs' (username: _: {
      name = "user-password-${username}";
      value = {
        files.user-password-hash = {
          neededFor = "users";
          restartUnits = lib.optional config.services.userborn.enable "userborn.service";
        };
        files.user-password.deploy = false;

        prompts.user-password = {
          display = {
            group = username;
            label = "password";
            required = false;
            helperText = "Leave empty to auto-generate a secure password";
          };
          type = "hidden";
          persist = true;
          description = "Password for user ${username}";
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
    }) resolved.usersNeedingPasswords;
  })

  (lib.mkIf (!isDarwin) {
    users.users = lib.mapAttrs (username: _: {
      hashedPasswordFile =
        config.clan.core.vars.generators."user-password-${username}".files.user-password-hash.path;
    }) resolved.usersNeedingPasswords;
  })

  (lib.mkIf (resolved.ownerUser != null) {
    adeci.primaryUser = lib.mkDefault resolved.ownerUser;
  })
]

{ ... }:
let
  # Default position definitions
  defaultPositions = {
    owner = {
      sudoAccess = true;
      generatePassword = true;
      homeDirectory = true;
      isSystemUser = false;
      description = "Machine owner with full administrative access";
    };

    admin = {
      sudoAccess = true;
      generatePassword = true;
      homeDirectory = true;
      isSystemUser = false;
      description = "Administrator with sudo access";
    };

    basic = {
      sudoAccess = false;
      generatePassword = true;
      homeDirectory = true;
      isSystemUser = false;
      description = "Regular user without administrative privileges";
    };

    service = {
      sudoAccess = false;
      generatePassword = false;
      homeDirectory = false;
      isSystemUser = true;
      description = "System service account";
    };
  };

  # Fallback defaults when no position is set
  fallbackPositionConfig = {
    sudoAccess = false;
    generatePassword = false;
    homeDirectory = true;
    isSystemUser = false;
    description = "Default (no position)";
  };

  # Shared module generator parameterized by platform
  mkPlatformModule =
    { isDarwin }:
    settings: machine:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      allPositions = defaultPositions // settings.positions;

      machineConfig = settings.machines.${machine.name} or { users = { }; };

      # =================================================================
      # Pre-validation: collect all configuration errors for clear reporting
      # =================================================================
      machineUserNames = builtins.attrNames machineConfig.users;

      # Find users referenced in machine but not defined globally
      undefinedUsers = lib.filter (u: !(settings.users ? ${u})) machineUserNames;

      # Find positions that don't exist
      getPosition =
        username: machineUserCfg:
        if machineUserCfg.position != null then
          machineUserCfg.position
        else
          (settings.users.${username} or { }).defaultPosition or null;

      usedPositions = lib.unique (
        lib.filter (p: p != null) (lib.mapAttrsToList getPosition machineConfig.users)
      );
      invalidPositions = lib.filter (p: !(allPositions ? ${p})) usedPositions;

      getUserConfig =
        username: machineUserConfig:
        let
          userDef =
            settings.users.${username}
              or (throw "User '${username}' referenced in machine '${machine.name}' but not defined in users");

          effectivePosition =
            if machineUserConfig.position != null then
              machineUserConfig.position
            else if userDef.defaultPosition or null != null then
              userDef.defaultPosition
            else
              null;

          positionConfig =
            if effectivePosition != null then
              allPositions.${effectivePosition}
                or (throw "Unknown position '${effectivePosition}' for user '${username}' on machine '${machine.name}'.")
            else
              fallbackPositionConfig;

          # Resolve each flag with priority: machine override > user override > position default
          effectiveFlags = {
            sudoAccess =
              if machineUserConfig.sudoAccess != null then
                machineUserConfig.sudoAccess
              else if userDef.sudoAccess or null != null then
                userDef.sudoAccess
              else
                positionConfig.sudoAccess;
            generatePassword =
              if machineUserConfig.generatePassword != null then
                machineUserConfig.generatePassword
              else if userDef.generatePassword or null != null then
                userDef.generatePassword
              else
                positionConfig.generatePassword;
            homeDirectory =
              if machineUserConfig.homeDirectory != null then
                machineUserConfig.homeDirectory
              else if userDef.homeDirectory or null != null then
                userDef.homeDirectory
              else
                positionConfig.homeDirectory;
            isSystemUser =
              if machineUserConfig.isSystemUser != null then
                machineUserConfig.isSystemUser
              else if userDef.isSystemUser or null != null then
                userDef.isSystemUser
              else
                positionConfig.isSystemUser;
          };

          effectiveUid = if machineUserConfig.uid != null then machineUserConfig.uid else userDef.uid;

          effectiveGroups =
            let
              base = if machineUserConfig.groups != null then machineUserConfig.groups else userDef.groups;
            in
            base ++ machineUserConfig.extraGroups;

          effectiveShell =
            let
              raw = if machineUserConfig.shell != null then machineUserConfig.shell else userDef.defaultShell;
            in
            if raw != null then pkgs.${raw} else null;

          effectiveSshKeys =
            let
              base =
                if machineUserConfig.sshAuthorizedKeys != null then
                  machineUserConfig.sshAuthorizedKeys
                else
                  userDef.sshAuthorizedKeys;
            in
            base ++ machineUserConfig.extraSshAuthorizedKeys;

          homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
        in
        {
          inherit
            username
            userDef
            positionConfig
            effectiveFlags
            effectiveUid
            effectiveGroups
            effectiveShell
            effectiveSshKeys
            effectivePosition
            homeDir
            ;
        };

      # Process all users for this machine
      allUserConfigs = lib.mapAttrs getUserConfig machineConfig.users;

      # Collect users who need passwords (NixOS only)
      usersNeedingPasswords =
        if isDarwin then
          { }
        else
          lib.filterAttrs (_: cfg: cfg.effectiveFlags.generatePassword) allUserConfigs;

      # Collect SSH keys for root from users with sudo access (NixOS only)
      rootSshKeys =
        if isDarwin then
          [ ]
        else
          lib.flatten (
            lib.mapAttrsToList (
              _: cfg: if cfg.effectiveFlags.sudoAccess then cfg.effectiveSshKeys else [ ]
            ) allUserConfigs
          );

    in
    {
      config = lib.mkMerge [
        # Configuration validation assertions
        {
          assertions = [
            {
              assertion = undefinedUsers == [ ];
              message = "Roster: Users referenced in machine '${machine.name}' but not defined: ${builtins.concatStringsSep ", " undefinedUsers}";
            }
            {
              assertion = invalidPositions == [ ];
              message = "Roster: Unknown positions used in machine '${machine.name}': ${builtins.concatStringsSep ", " invalidPositions}. Available: ${builtins.concatStringsSep ", " (builtins.attrNames allPositions)}";
            }
          ];
        }

        # User accounts
        {
          users.users = lib.mapAttrs (
            username: cfg:
            lib.mkMerge [
              # Base configuration (platform-aware)
              (
                if isDarwin then
                  {
                    name = username;
                    uid = cfg.effectiveUid;
                    home = cfg.homeDir;
                    description = cfg.userDef.description;
                    openssh.authorizedKeys.keys = cfg.effectiveSshKeys;
                  }
                else
                  {
                    uid = cfg.effectiveUid;
                    description = cfg.userDef.description;
                    isSystemUser = cfg.effectiveFlags.isSystemUser;
                    isNormalUser = !cfg.effectiveFlags.isSystemUser;
                    createHome = cfg.effectiveFlags.homeDirectory;
                    home = if cfg.effectiveFlags.homeDirectory then cfg.homeDir else "/var/empty";
                    group = if cfg.effectiveFlags.isSystemUser then username else "users";
                    extraGroups = cfg.effectiveGroups ++ (lib.optional cfg.effectiveFlags.sudoAccess "wheel");
                    openssh.authorizedKeys.keys = cfg.effectiveSshKeys;
                  }
              )

              # Shell configuration
              (lib.mkIf (cfg.effectiveShell != null) {
                shell = cfg.effectiveShell;
              })
            ]
          ) allUserConfigs;
        }

        # NixOS-only: Root SSH access for admins
        (lib.mkIf (!isDarwin) {
          users.users.root.openssh.authorizedKeys.keys = rootSshKeys;
        })

        # NixOS-only: System user groups
        (lib.mkIf (!isDarwin) {
          users.groups = lib.mapAttrs' (username: _: lib.nameValuePair username { }) (
            lib.filterAttrs (_: cfg: cfg.effectiveFlags.isSystemUser) allUserConfigs
          );
        })

        # NixOS-only: Password generators
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
          }) usersNeedingPasswords;
        })

        # NixOS-only: hashed password files
        (lib.mkIf (!isDarwin) {
          users.users = lib.mapAttrs (username: _: {
            hashedPasswordFile =
              config.clan.core.vars.generators."user-password-${username}".files.user-password-hash.path;
          }) usersNeedingPasswords;
        })
      ];
    };
in
{
  _class = "clan.service";

  manifest.name = "@adeci/roster";
  manifest.description = "Hierarchical user management with position-based access control";
  manifest.categories = [ "System" ];
  manifest.readme = builtins.readFile ./README.md;

  roles.default = {
    description = "Roster user management";

    interface =
      { lib, ... }:
      {
        options = {
          # Custom position definitions (extends/overrides defaults)
          positions = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  sudoAccess = lib.mkOption {
                    type = lib.types.bool;
                    description = "Whether users in this position have sudo access";
                  };
                  generatePassword = lib.mkOption {
                    type = lib.types.bool;
                    description = "Whether to auto-generate passwords for users in this position";
                  };
                  homeDirectory = lib.mkOption {
                    type = lib.types.bool;
                    description = "Whether users in this position have a home directory";
                  };
                  isSystemUser = lib.mkOption {
                    type = lib.types.bool;
                    description = "Whether users in this position are system users";
                  };
                  description = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    description = "Description of this position";
                  };
                };
              }
            );
            default = { };
            example = lib.literalExpression ''
              {
                developer = {
                  sudoAccess = false;
                  generatePassword = true;
                  homeDirectory = true;
                  isSystemUser = false;
                  description = "Developer without sudo access";
                };
              }
            '';
            description = "Custom position definitions that extend or override the defaults";
          };

          # Global user definitions
          users = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  uid = lib.mkOption {
                    type = lib.types.int;
                    example = 1000;
                    description = "User's UID (must be consistent across machines)";
                  };
                  defaultPosition = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    example = "owner";
                    description = "Default position for this user (owner/admin/basic/service or custom). Null means no position; flags use fallback defaults unless overridden.";
                  };
                  description = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    example = "Alice Smith";
                    description = "Human-readable description of the user";
                  };
                  groups = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    example = [
                      "wheel"
                      "video"
                      "audio"
                    ];
                    description = "Default groups for this user";
                  };
                  sshAuthorizedKeys = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    example = [ "ssh-ed25519 AAAAC3Nza... user@host" ];
                    description = "SSH public keys for this user";
                  };
                  defaultShell = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    example = "fish";
                    description = "Default shell name (e.g., \"fish\", \"zsh\", \"bash\") — resolved to pkgs.\${name} in the generated module";
                  };
                  sudoAccess = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Override position's sudoAccess flag";
                  };
                  generatePassword = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Override position's generatePassword flag";
                  };
                  homeDirectory = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Override position's homeDirectory flag";
                  };
                  isSystemUser = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Override position's isSystemUser flag";
                  };
                };
              }
            );
            default = { };
            example = lib.literalExpression ''
              {
                alice = {
                  uid = 1000;
                  defaultPosition = "owner";
                  description = "Alice";
                  groups = [ "wheel" "video" ];
                  sshAuthorizedKeys = [ "ssh-ed25519 AAAAC3Nza..." ];
                  defaultShell = "fish";
                };
              }
            '';
            description = "Global user definitions";
          };

          # Machine-specific user assignments
          machines = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  users = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        options = {
                          position = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            example = "admin";
                            description = "Override position for this user on this machine";
                          };
                          uid = lib.mkOption {
                            type = lib.types.nullOr lib.types.int;
                            default = null;
                            example = 1001;
                            description = "Override UID for this user on this machine";
                          };
                          groups = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.str);
                            default = null;
                            example = [
                              "docker"
                              "libvirt"
                            ];
                            description = "Override groups for this user on this machine";
                          };
                          extraGroups = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            example = [ "docker" ];
                            description = "Additional groups for this user on this machine (adds to default groups)";
                          };
                          shell = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            example = "zsh";
                            description = "Override shell name for this user on this machine";
                          };
                          sshAuthorizedKeys = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.str);
                            default = null;
                            example = [ "ssh-ed25519 AAAAC3Nza... workstation" ];
                            description = "Override SSH keys for this user on this machine";
                          };
                          extraSshAuthorizedKeys = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            example = [ "ssh-ed25519 AAAAC3Nza... extra-key" ];
                            description = "Additional SSH keys for this user on this machine";
                          };
                          sudoAccess = lib.mkOption {
                            type = lib.types.nullOr lib.types.bool;
                            default = null;
                            description = "Override sudoAccess for this user on this machine";
                          };
                          generatePassword = lib.mkOption {
                            type = lib.types.nullOr lib.types.bool;
                            default = null;
                            description = "Override generatePassword for this user on this machine";
                          };
                          homeDirectory = lib.mkOption {
                            type = lib.types.nullOr lib.types.bool;
                            default = null;
                            description = "Override homeDirectory for this user on this machine";
                          };
                          isSystemUser = lib.mkOption {
                            type = lib.types.nullOr lib.types.bool;
                            default = null;
                            description = "Override isSystemUser for this user on this machine";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Users assigned to this machine with optional overrides";
                  };
                };
              }
            );
            default = { };
            example = lib.literalExpression ''
              {
                server1 = {
                  users.alice = { };
                  users.bob = {
                    position = "admin";
                    extraGroups = [ "docker" ];
                  };
                };
              }
            '';
            description = "Machine-specific user assignments and overrides";
          };
        };
      };

    perInstance =
      { settings, machine, ... }:
      {
        nixosModule = mkPlatformModule { isDarwin = false; } settings machine;
        darwinModule = mkPlatformModule { isDarwin = true; } settings machine;
      };
  };

  # Applied to all machines regardless of instance
  perMachine = {
    nixosModule = {
      users.mutableUsers = false;
    };
    darwinModule = { };
  };
}

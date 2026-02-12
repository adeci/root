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

  # Shared module generator parameterized by platform
  mkPlatformModule =
    { isDarwin }:
    settings: machine:
    {
      config,
      lib,
      pkgs,
      inputs,
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
              throw "No position defined for user '${username}' on machine '${machine.name}'.";

          positionConfig =
            allPositions.${effectivePosition}
              or (throw "Unknown position '${effectivePosition}' for user '${username}' on machine '${machine.name}'.");

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

          effectiveHomeProfiles =
            let
              base =
                if machineUserConfig.homeProfiles != null then
                  machineUserConfig.homeProfiles
                else
                  userDef.homeProfiles;
            in
            base ++ machineUserConfig.extraHomeProfiles;

          homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
        in
        {
          inherit
            username
            userDef
            positionConfig
            effectiveUid
            effectiveGroups
            effectiveShell
            effectiveSshKeys
            effectiveHomeProfiles
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
          lib.filterAttrs (_: cfg: cfg.positionConfig.generatePassword) allUserConfigs;

      # Collect SSH keys for root from users with sudo access (NixOS only)
      rootSshKeys =
        if isDarwin then
          [ ]
        else
          lib.flatten (
            lib.mapAttrsToList (
              _: cfg: if cfg.positionConfig.sudoAccess then cfg.effectiveSshKeys else [ ]
            ) allUserConfigs
          );

      # Collect users with home-manager profiles
      usersWithHomeProfiles = lib.filterAttrs (_: cfg: cfg.effectiveHomeProfiles != [ ]) allUserConfigs;

      anyUserHasHomeProfiles = usersWithHomeProfiles != { };

      # Resolve profile path strings to actual imports
      resolveProfiles = profiles: map (p: import (inputs.self + "/${p}")) profiles;

      # HM module to import
      hmModule =
        if isDarwin then
          inputs.home-manager.darwinModules.home-manager
        else
          inputs.home-manager.nixosModules.home-manager;

    in
    {
      # Import home-manager module when any user has profiles
      imports = lib.optionals anyUserHasHomeProfiles [ hmModule ];

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
                    isSystemUser = cfg.positionConfig.isSystemUser;
                    isNormalUser = !cfg.positionConfig.isSystemUser;
                    createHome = cfg.positionConfig.homeDirectory;
                    home = if cfg.positionConfig.homeDirectory then cfg.homeDir else "/var/empty";
                    group = if cfg.positionConfig.isSystemUser then username else "users";
                    extraGroups = cfg.effectiveGroups ++ (lib.optional cfg.positionConfig.sudoAccess "wheel");
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
            lib.filterAttrs (_: cfg: cfg.positionConfig.isSystemUser) allUserConfigs
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

        # Home-manager configuration when users have profiles
        (lib.mkIf anyUserHasHomeProfiles {
          home-manager = {
            useGlobalPkgs = settings.homeManager.useGlobalPkgs;
            useUserPackages = settings.homeManager.useUserPackages;
            backupFileExtension = lib.mkDefault "backup";
            extraSpecialArgs = {
              inherit inputs;
              rosterMachine = machine.name;
            };

            users = lib.mapAttrs (username: cfg: {
              imports = resolveProfiles cfg.effectiveHomeProfiles;
              home.username = username;
              home.homeDirectory = cfg.homeDir;
              home.stateVersion = lib.mkDefault (if isDarwin then "24.11" else config.system.stateVersion);
            }) usersWithHomeProfiles;
          };
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
                    type = lib.types.str;
                    example = "owner";
                    description = "Default position for this user (owner/admin/basic/service or custom)";
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
                  homeProfiles = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    example = [
                      "home-manager/profiles/base.nix"
                      "home-manager/profiles/shell.nix"
                    ];
                    description = "Home-manager profile paths relative to flake root, imported for this user on all machines";
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
                  homeProfiles = [ "home-manager/profiles/base.nix" ];
                };
              }
            '';
            description = "Global user definitions";
          };

          # Home-manager settings
          homeManager = lib.mkOption {
            type = lib.types.submodule {
              options = {
                useGlobalPkgs = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to use the system's nixpkgs for home-manager packages";
                };
                useUserPackages = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Whether to install user packages via home-manager";
                };
              };
            };
            default = { };
            example = lib.literalExpression ''
              {
                useGlobalPkgs = true;
                useUserPackages = true;
              }
            '';
            description = "Home-manager configuration settings";
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
                          homeProfiles = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.str);
                            default = null;
                            example = [ "home-manager/profiles/base.nix" ];
                            description = "Override home-manager profiles for this user on this machine (replaces defaults)";
                          };
                          extraHomeProfiles = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            example = [ "home-manager/profiles/dev.nix" ];
                            description = "Additional home-manager profiles for this user on this machine (adds to defaults)";
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

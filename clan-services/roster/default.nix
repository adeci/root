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
in
{
  _class = "clan.service";

  manifest.name = "@onix/roster";
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
                    type = lib.types.nullOr lib.types.package;
                    default = null;
                    example = lib.literalExpression "pkgs.fish";
                    description = "Default shell package for this user (e.g., pkgs.bash, pkgs.fish, or a custom wrapped shell)";
                  };
                  packages = lib.mkOption {
                    type = lib.types.listOf lib.types.package;
                    default = [ ];
                    example = lib.literalExpression "[ pkgs.git pkgs.vim ]";
                    description = "Default packages to install for this user on all systems";
                  };
                  # Home-manager integration
                  homeModules = lib.mkOption {
                    type = lib.types.listOf lib.types.deferredModule;
                    default = [ ];
                    example = lib.literalExpression "[ ./home/git.nix ./home/shell.nix ]";
                    description = "Home-manager modules applied to this user on all machines";
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
                  defaultShell = pkgs.fish;
                };
              }
            '';
            description = "Global user definitions";
          };

          # Home-manager settings
          homeManager = lib.mkOption {
            type = lib.types.submodule {
              options = {
                module = lib.mkOption {
                  type = lib.types.nullOr lib.types.deferredModule;
                  default = null;
                  description = ''
                    The home-manager NixOS module to import.
                    Set this to enable home-manager integration.

                    Example: `inputs.home-manager.nixosModules.home-manager`
                  '';
                  example = lib.literalExpression "inputs.home-manager.nixosModules.home-manager";
                };
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
                extraSpecialArgs = lib.mkOption {
                  type = lib.types.attrs;
                  default = { };
                  example = lib.literalExpression "{ inherit inputs; }";
                  description = "Extra arguments passed to all home-manager modules";
                };
                sharedModules = lib.mkOption {
                  type = lib.types.listOf lib.types.deferredModule;
                  default = [ ];
                  example = lib.literalExpression "[ ./home/common.nix ]";
                  description = "Home-manager modules applied to all users";
                };
              };
            };
            default = { };
            example = lib.literalExpression ''
              {
                module = inputs.home-manager.nixosModules.home-manager;
                useGlobalPkgs = true;
                sharedModules = [ ./home/common.nix ];
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
                            type = lib.types.nullOr lib.types.package;
                            default = null;
                            example = lib.literalExpression "pkgs.zsh";
                            description = "Override shell package for this user on this machine";
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
                          packages = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.package);
                            default = null;
                            example = lib.literalExpression "[ pkgs.docker-compose ]";
                            description = "Override packages for this user on this machine (replaces default packages)";
                          };
                          extraPackages = lib.mkOption {
                            type = lib.types.listOf lib.types.package;
                            default = [ ];
                            example = lib.literalExpression "[ pkgs.kubectl ]";
                            description = "Additional packages for this user on this machine (adds to default packages)";
                          };
                          # Home-manager integration
                          homeModules = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.deferredModule);
                            default = null;
                            example = lib.literalExpression "[ ./home/server.nix ]";
                            description = "Override home-manager modules for this user on this machine (replaces default homeModules)";
                          };
                          extraHomeModules = lib.mkOption {
                            type = lib.types.listOf lib.types.deferredModule;
                            default = [ ];
                            example = lib.literalExpression "[ ./home/workstation.nix ]";
                            description = "Additional home-manager modules for this user on this machine (adds to default homeModules)";
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
                  users.alice = { };  # Use defaults from user definition
                  users.bob = {
                    position = "admin";  # Override position
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
        nixosModule =
          # We need to structure this carefully:
          # 1. imports must be at module level, not inside config
          # 2. We can't conditionally import based on runtime values
          # So we build the module structure with imports at the top level
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            allPositions = defaultPositions // settings.positions;

            machineConfig = settings.machines.${machine.name} or { users = { }; };

            # Home-manager is enabled when the module is provided
            homeManagerEnabled = settings.homeManager.module != null;

            # =================================================================
            # Pre-validation: collect all configuration errors for clear reporting
            # =================================================================
            machineUserNames = builtins.attrNames machineConfig.users;

            # Find users referenced in machine but not defined globally
            undefinedUsers = lib.filter (u: !(settings.users ? ${u})) machineUserNames;

            # Find positions that don't exist (from both user defaults and machine overrides)
            # Note: handles undefined users gracefully (they're caught by separate assertion)
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

                # Determine effective position (machine override takes precedence)
                effectivePosition =
                  if machineUserConfig.position != null then
                    machineUserConfig.position
                  else if userDef.defaultPosition or null != null then
                    userDef.defaultPosition
                  else
                    throw "No position defined for user '${username}' on machine '${machine.name}'. Either set defaultPosition in user definition or provide position in machine assignment.";

                # Look up position config (will throw if position doesn't exist)
                positionConfig =
                  allPositions.${effectivePosition}
                    or (throw "Unknown position '${effectivePosition}' for user '${username}' on machine '${machine.name}'. Available positions: ${builtins.concatStringsSep ", " (builtins.attrNames allPositions)}");

                # =================================================================
                # Override Resolution Pattern:
                # For list-type options (groups, sshKeys, packages, homeModules):
                #   - If machine.<option> is set: use it (replaces user default entirely)
                #   - Otherwise: use user default
                #   - In both cases: append machine.extra<Option> to the result
                #
                # This allows:
                #   - Full override: set groups = [...] on machine user
                #   - Additive only: leave groups null, set extraGroups = [...]
                # =================================================================

                effectiveUid = if machineUserConfig.uid != null then machineUserConfig.uid else userDef.uid;

                effectiveGroups =
                  let
                    base = if machineUserConfig.groups != null then machineUserConfig.groups else userDef.groups;
                  in
                  base ++ machineUserConfig.extraGroups;

                effectiveShell =
                  if machineUserConfig.shell != null then machineUserConfig.shell else userDef.defaultShell;

                effectiveSshKeys =
                  let
                    base =
                      if machineUserConfig.sshAuthorizedKeys != null then
                        machineUserConfig.sshAuthorizedKeys
                      else
                        userDef.sshAuthorizedKeys;
                  in
                  base ++ machineUserConfig.extraSshAuthorizedKeys;

                effectivePackages =
                  let
                    base =
                      if machineUserConfig.packages != null then
                        machineUserConfig.packages
                      else
                        (userDef.packages or [ ]);
                  in
                  base ++ machineUserConfig.extraPackages;

                effectiveHomeModules =
                  let
                    base =
                      if machineUserConfig.homeModules != null then
                        machineUserConfig.homeModules
                      else
                        userDef.homeModules;
                  in
                  base ++ machineUserConfig.extraHomeModules;

              in
              {
                inherit username userDef positionConfig;
                inherit
                  effectiveUid
                  effectiveGroups
                  effectiveShell
                  effectiveSshKeys
                  effectivePackages
                  effectiveHomeModules
                  ;
                inherit effectivePosition;
              };

            # Process all users for this machine
            allUserConfigs = lib.mapAttrs getUserConfig machineConfig.users;

            # Collect users who need passwords
            usersNeedingPasswords = lib.filterAttrs (
              _: cfg: cfg.positionConfig.generatePassword
            ) allUserConfigs;

            # Collect SSH keys for root from users with sudo access
            rootSshKeys = lib.flatten (
              lib.mapAttrsToList (
                _: cfg: if cfg.positionConfig.sudoAccess then cfg.effectiveSshKeys else [ ]
              ) allUserConfigs
            );

            # Collect users with home-manager modules
            usersWithHomeModules = lib.filterAttrs (_: cfg: cfg.effectiveHomeModules != [ ]) allUserConfigs;

            anyUserHasHomeModules = usersWithHomeModules != { };

            usersWithHomeModulesList = builtins.attrNames usersWithHomeModules;

          in
          {
            # Import home-manager module when enabled
            imports = lib.optionals homeManagerEnabled [ settings.homeManager.module ];

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
                    # Base configuration
                    {
                      uid = cfg.effectiveUid;
                      description = cfg.userDef.description;
                      isSystemUser = cfg.positionConfig.isSystemUser;
                      isNormalUser = !cfg.positionConfig.isSystemUser;
                      createHome = cfg.positionConfig.homeDirectory;
                      home = if cfg.positionConfig.homeDirectory then "/home/${username}" else "/var/empty";
                      group = if cfg.positionConfig.isSystemUser then username else "users";
                      extraGroups = cfg.effectiveGroups ++ (lib.optional cfg.positionConfig.sudoAccess "wheel");
                      openssh.authorizedKeys.keys = cfg.effectiveSshKeys;
                    }

                    # Shell configuration
                    (lib.mkIf (cfg.effectiveShell != null) {
                      shell = cfg.effectiveShell;
                    })

                    # Password configuration
                    (lib.mkIf cfg.positionConfig.generatePassword {
                      hashedPasswordFile =
                        config.clan.core.vars.generators."user-password-${username}".files.user-password-hash.path;
                    })

                    # Packages configuration
                    (lib.mkIf (cfg.effectivePackages != [ ]) {
                      packages = cfg.effectivePackages;
                    })
                  ]
                ) allUserConfigs;
              }

              # Root SSH access for admins
              {
                users.users.root.openssh.authorizedKeys.keys = rootSshKeys;
              }

              # System user groups (system users need their own group)
              {
                users.groups = lib.mapAttrs' (username: _: lib.nameValuePair username { }) (
                  lib.filterAttrs (_: cfg: cfg.positionConfig.isSystemUser) allUserConfigs
                );
              }

              # Password generators
              {
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

                    share = true; # Same password across all machines

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
              }

              # Warning when home-manager modules are configured but module not provided
              (lib.mkIf (anyUserHasHomeModules && !homeManagerEnabled) {
                warnings = [
                  ''
                    Roster: Home-manager modules are configured for users [${builtins.concatStringsSep ", " usersWithHomeModulesList}]
                    on machine '${machine.name}', but homeManager.module is not set.

                    To enable home-manager support, add to your roster settings:
                      homeManager.module = inputs.home-manager.nixosModules.home-manager;

                    The homeModules configuration will be ignored until this is set.
                  ''
                ];
              })

              # Home-manager configuration when enabled and users have modules
              (lib.mkIf (anyUserHasHomeModules && homeManagerEnabled) {
                home-manager = {
                  useGlobalPkgs = settings.homeManager.useGlobalPkgs;
                  useUserPackages = settings.homeManager.useUserPackages;
                  backupFileExtension = lib.mkDefault "backup";
                  extraSpecialArgs = settings.homeManager.extraSpecialArgs // {
                    # Inject roster context for home modules to use
                    rosterMachine = machine.name;
                  };
                  sharedModules = settings.homeManager.sharedModules;

                  users = lib.mapAttrs (username: cfg: {
                    imports = cfg.effectiveHomeModules;
                    home.username = username;
                    home.homeDirectory = "/home/${username}";
                    # Match NixOS stateVersion by default for consistency
                    home.stateVersion = lib.mkDefault config.system.stateVersion;
                  }) usersWithHomeModules;
                };
              })
            ];
          };
      };
  };

  # Applied to all machines regardless of instance
  perMachine = {
    nixosModule = {
      # Immutable users to ensure roster has exclusive control over user management
      users.mutableUsers = false;
    };
  };
}

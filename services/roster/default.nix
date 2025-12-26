_:
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
            description = "Custom position definitions that extend or override the defaults";
          };

          # Global user definitions
          users = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  uid = lib.mkOption {
                    type = lib.types.int;
                    description = "User's UID (must be consistent across machines)";
                  };
                  defaultPosition = lib.mkOption {
                    type = lib.types.str;
                    description = "Default position for this user (owner/admin/basic/service or custom)";
                  };
                  description = lib.mkOption {
                    type = lib.types.str;
                    default = "";
                    description = "Human-readable description of the user";
                  };
                  groups = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Default groups for this user";
                  };
                  sshAuthorizedKeys = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "SSH public keys for this user";
                  };
                  defaultShell = lib.mkOption {
                    type = lib.types.nullOr lib.types.package;
                    default = null;
                    description = "Default shell package for this user (e.g., pkgs.bash, pkgs.fish, or a custom wrapped shell)";
                  };
                  packages = lib.mkOption {
                    type = lib.types.listOf lib.types.package;
                    default = [ ];
                    description = "Default packages to install for this user on all systems";
                  };
                  # Home-manager integration
                  homeModules = lib.mkOption {
                    type = lib.types.listOf lib.types.deferredModule;
                    default = [ ];
                    description = "Home-manager modules applied to this user on all machines";
                  };
                };
              }
            );
            default = { };
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
                  description = "Extra arguments passed to all home-manager modules";
                };
                sharedModules = lib.mkOption {
                  type = lib.types.listOf lib.types.deferredModule;
                  default = [ ];
                  description = "Home-manager modules applied to all users";
                };
              };
            };
            default = { };
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
                            description = "Override position for this user on this machine";
                          };
                          uid = lib.mkOption {
                            type = lib.types.nullOr lib.types.int;
                            default = null;
                            description = "Override UID for this user on this machine";
                          };
                          groups = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.str);
                            default = null;
                            description = "Override groups for this user on this machine";
                          };
                          extraGroups = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            description = "Additional groups for this user on this machine (adds to default groups)";
                          };
                          shell = lib.mkOption {
                            type = lib.types.nullOr lib.types.package;
                            default = null;
                            description = "Override shell package for this user on this machine";
                          };
                          sshAuthorizedKeys = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.str);
                            default = null;
                            description = "Override SSH keys for this user on this machine";
                          };
                          extraSshAuthorizedKeys = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            description = "Additional SSH keys for this user on this machine";
                          };
                          packages = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.package);
                            default = null;
                            description = "Override packages for this user on this machine (replaces default packages)";
                          };
                          extraPackages = lib.mkOption {
                            type = lib.types.listOf lib.types.package;
                            default = [ ];
                            description = "Additional packages for this user on this machine (adds to default packages)";
                          };
                          # Home-manager integration
                          homeModules = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.deferredModule);
                            default = null;
                            description = "Override home-manager modules for this user on this machine (replaces default homeModules)";
                          };
                          extraHomeModules = lib.mkOption {
                            type = lib.types.listOf lib.types.deferredModule;
                            default = [ ];
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

                # Determine effective values (machine overrides > user defaults)
                effectiveUid = if machineUserConfig.uid != null then machineUserConfig.uid else userDef.uid;
                effectiveGroups =
                  if machineUserConfig.groups != null then
                    machineUserConfig.groups ++ machineUserConfig.extraGroups
                  else
                    userDef.groups ++ machineUserConfig.extraGroups;
                effectiveShell =
                  if machineUserConfig.shell != null then machineUserConfig.shell else userDef.defaultShell;
                effectiveSshKeys =
                  if machineUserConfig.sshAuthorizedKeys != null then
                    machineUserConfig.sshAuthorizedKeys ++ machineUserConfig.extraSshAuthorizedKeys
                  else
                    userDef.sshAuthorizedKeys ++ machineUserConfig.extraSshAuthorizedKeys;
                effectivePackages =
                  if machineUserConfig.packages != null then
                    machineUserConfig.packages ++ machineUserConfig.extraPackages
                  else
                    (userDef.packages or [ ]) ++ machineUserConfig.extraPackages;

                # Home-manager modules resolution (same pattern as groups/packages)
                effectiveHomeModules =
                  if machineUserConfig.homeModules != null then
                    machineUserConfig.homeModules
                  else
                    userDef.homeModules ++ machineUserConfig.extraHomeModules;

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
                      useDefaultShell = false;
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

              # System user groups
              {
                users.groups = lib.listToAttrs (
                  lib.filter (g: g.value != { }) (
                    lib.mapAttrsToList (
                      username: cfg:
                      if cfg.positionConfig.isSystemUser then
                        {
                          name = username;
                          value = { };
                        }
                      else
                        {
                          name = "";
                          value = { };
                        }
                    ) allUserConfigs
                  )
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

              # Make users immutable
              {
                users.mutableUsers = false;
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
}

_:
let
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

  fallbackPositionConfig = {
    sudoAccess = false;
    generatePassword = false;
    homeDirectory = true;
    isSystemUser = false;
    description = "Default (no position)";
  };

  resolve = import ./lib/resolve.nix;
  generate = import ./lib/generate.nix;

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
      resolved = resolve {
        inherit
          lib
          pkgs
          settings
          machine
          isDarwin
          defaultPositions
          fallbackPositionConfig
          ;
      };
    in
    {
      config = lib.mkMerge (generate {
        inherit
          lib
          pkgs
          config
          inputs
          settings
          machine
          isDarwin
          resolved
          ;
      });
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
          # Home-manager profile definitions (named groups of HM module names)
          homeManagerProfiles = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            example = lib.literalExpression ''
              {
                base = "home-manager/profiles/base.nix";
                desktop = "home-manager/profiles/desktop.nix";
              }
            '';
            description = "Named HM profiles mapping to file paths (relative to flake root)";
          };

          # Darwin home.stateVersion (NixOS derives it from system.stateVersion)
          darwinHomeStateVersion = lib.mkOption {
            type = lib.types.str;
            default = "25.11";
            description = "home.stateVersion for Darwin machines";
          };

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
                  homeManagerProfiles = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    example = [
                      "base"
                      "desktop"
                    ];
                    description = "Default HM profile names for this user";
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
                  homeManagerProfiles = [ "base" ];
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
                          homeManagerProfiles = lib.mkOption {
                            type = lib.types.nullOr (lib.types.listOf lib.types.str);
                            default = null;
                            example = [ "base" ];
                            description = "Override HM profiles for this user on this machine";
                          };
                          extraHomeManagerProfiles = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            example = [ "desktop" ];
                            description = "Additional HM profiles on top of the user's defaults";
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
                    extraHomeManagerProfiles = [ "desktop" ];
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
    nixosModule =
      { lib, ... }:
      {
        options.adeci.primaryUser = lib.mkOption {
          type = lib.types.str;
          default = "alex";
          description = "Primary user (owner) of this machine, derived from roster";
        };
        config.users.mutableUsers = false;
      };
    darwinModule =
      { lib, ... }:
      {
        options.adeci.primaryUser = lib.mkOption {
          type = lib.types.str;
          default = "alex";
          description = "Primary user (owner) of this machine, derived from roster";
        };
      };
  };
}

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
    description = "User management";

    interface =
      { lib, ... }:
      {
        options = {
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
                    description = "Default position for this user. Null means no position; flags use fallback defaults unless overridden.";
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
                    description = "Default shell name (resolved to pkgs.\${name} in the generated module)";
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
            description = "Global user definitions";
          };

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
                            description = "Additional groups for this user on this machine";
                          };
                          shell = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Override shell name for this user on this machine";
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

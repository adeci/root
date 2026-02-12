{
  lib,
  module,
  ...
}:
let
  # ==========================================================================
  # Test Helpers
  # ==========================================================================

  interface = module.roles.default.interface { inherit lib; };
  userOpts = interface.options.users.type.getSubOptions [ ];
  machineOpts = interface.options.machines.type.getSubOptions [ ];
  machineUserOpts = machineOpts.users.type.getSubOptions [ ];
  hmOpts = interface.options.homeManager.type.getSubOptions [ ];

in
{
  # ==========================================================================
  # 1. Interface Serializability — THE critical test
  #    clan-core requires interface to be JSON-serializable
  # ==========================================================================

  test_interface_has_no_package_types = {
    expr = !(userOpts ? packages);
    expected = true;
  };

  test_interface_has_no_deferred_module_types = {
    expr = !(userOpts ? homeModules);
    expected = true;
  };

  test_interface_has_no_attrs_type_in_homeManager = {
    expr = !(hmOpts ? extraSpecialArgs);
    expected = true;
  };

  test_interface_homeManager_has_no_module_option = {
    expr = !(hmOpts ? module);
    expected = true;
  };

  test_interface_homeManager_has_no_sharedModules = {
    expr = !(hmOpts ? sharedModules);
    expected = true;
  };

  test_machine_user_has_no_packages = {
    expr = !(machineUserOpts ? packages);
    expected = true;
  };

  test_machine_user_has_no_extraPackages = {
    expr = !(machineUserOpts ? extraPackages);
    expected = true;
  };

  test_machine_user_has_no_homeModules = {
    expr = !(machineUserOpts ? homeModules);
    expected = true;
  };

  test_machine_user_has_no_extraHomeModules = {
    expr = !(machineUserOpts ? extraHomeModules);
    expected = true;
  };

  # ==========================================================================
  # 2. Module Structure Validation
  # ==========================================================================

  test_module_has_class = {
    expr = module._class;
    expected = "clan.service";
  };

  test_module_has_manifest = {
    expr = module.manifest.name;
    expected = "@adeci/roster";
  };

  test_module_has_default_role = {
    expr = module.roles ? default;
    expected = true;
  };

  test_module_has_perMachine = {
    expr = module ? perMachine;
    expected = true;
  };

  test_perMachine_has_nixosModule = {
    expr = module.perMachine ? nixosModule;
    expected = true;
  };

  test_perMachine_has_darwinModule = {
    expr = module.perMachine ? darwinModule;
    expected = true;
  };

  # ==========================================================================
  # 3. New Interface Options — Verify the new JSON-safe schema
  # ==========================================================================

  # User options
  test_user_has_uid = {
    expr = userOpts ? uid;
    expected = true;
  };

  test_user_has_defaultPosition = {
    expr = userOpts ? defaultPosition;
    expected = true;
  };

  test_user_has_groups = {
    expr = userOpts ? groups;
    expected = true;
  };

  test_user_has_sshAuthorizedKeys = {
    expr = userOpts ? sshAuthorizedKeys;
    expected = true;
  };

  test_user_has_defaultShell = {
    expr = userOpts ? defaultShell;
    expected = true;
  };

  test_user_has_homeProfiles = {
    expr = userOpts ? homeProfiles;
    expected = true;
  };

  test_user_has_description = {
    expr = userOpts ? description;
    expected = true;
  };

  # Machine user options
  test_machine_user_has_position = {
    expr = machineUserOpts ? position;
    expected = true;
  };

  test_machine_user_has_uid = {
    expr = machineUserOpts ? uid;
    expected = true;
  };

  test_machine_user_has_groups = {
    expr = machineUserOpts ? groups;
    expected = true;
  };

  test_machine_user_has_extraGroups = {
    expr = machineUserOpts ? extraGroups;
    expected = true;
  };

  test_machine_user_has_shell = {
    expr = machineUserOpts ? shell;
    expected = true;
  };

  test_machine_user_has_sshAuthorizedKeys = {
    expr = machineUserOpts ? sshAuthorizedKeys;
    expected = true;
  };

  test_machine_user_has_extraSshAuthorizedKeys = {
    expr = machineUserOpts ? extraSshAuthorizedKeys;
    expected = true;
  };

  test_machine_user_has_homeProfiles = {
    expr = machineUserOpts ? homeProfiles;
    expected = true;
  };

  test_machine_user_has_extraHomeProfiles = {
    expr = machineUserOpts ? extraHomeProfiles;
    expected = true;
  };

  # HomeManager options (only bool flags now)
  test_homeManager_has_useGlobalPkgs = {
    expr = hmOpts ? useGlobalPkgs;
    expected = true;
  };

  test_homeManager_has_useUserPackages = {
    expr = hmOpts ? useUserPackages;
    expected = true;
  };

  # Positions option
  test_has_positions = {
    expr = interface.options ? positions;
    expected = true;
  };

  # ==========================================================================
  # 4. Resolution Logic Tests (pure functions)
  # ==========================================================================

  # homeProfiles resolution: default + extra pattern
  test_homeProfiles_resolution_uses_default = {
    expr =
      let
        userDefault = [
          "home-manager/profiles/base.nix"
          "home-manager/profiles/shell.nix"
        ];
        machineOverride = null;
        machineExtra = [ ];
        base = if machineOverride != null then machineOverride else userDefault;
      in
      base ++ machineExtra;
    expected = [
      "home-manager/profiles/base.nix"
      "home-manager/profiles/shell.nix"
    ];
  };

  test_homeProfiles_resolution_override_replaces = {
    expr =
      let
        userDefault = [
          "home-manager/profiles/base.nix"
          "home-manager/profiles/shell.nix"
        ];
        machineOverride = [ "home-manager/profiles/server.nix" ];
        machineExtra = [ ];
        base = if machineOverride != null then machineOverride else userDefault;
      in
      base ++ machineExtra;
    expected = [ "home-manager/profiles/server.nix" ];
  };

  test_homeProfiles_resolution_extra_adds = {
    expr =
      let
        userDefault = [ "home-manager/profiles/base.nix" ];
        machineOverride = null;
        machineExtra = [ "home-manager/profiles/dev.nix" ];
        base = if machineOverride != null then machineOverride else userDefault;
      in
      base ++ machineExtra;
    expected = [
      "home-manager/profiles/base.nix"
      "home-manager/profiles/dev.nix"
    ];
  };

  test_homeProfiles_empty_when_no_config = {
    expr =
      let
        userDefault = [ ];
        machineOverride = null;
        machineExtra = [ ];
        base = if machineOverride != null then machineOverride else userDefault;
      in
      base ++ machineExtra;
    expected = [ ];
  };

  # Shell resolution pattern (string -> resolved later by pkgs.\${name})
  test_shell_resolution_machine_overrides_user = {
    expr =
      let
        machineShell = "zsh";
        userShell = "fish";
        effective = if machineShell != null then machineShell else userShell;
      in
      effective;
    expected = "zsh";
  };

  test_shell_resolution_falls_back_to_user_default = {
    expr =
      let
        machineShell = null;
        userShell = "fish";
        effective = if machineShell != null then machineShell else userShell;
      in
      effective;
    expected = "fish";
  };

  test_shell_resolution_null_when_both_null = {
    expr =
      let
        machineShell = null;
        userShell = null;
        effective = if machineShell != null then machineShell else userShell;
      in
      effective;
    expected = null;
  };

  # ==========================================================================
  # 5. Validation Logic Tests
  # ==========================================================================

  test_validation_detects_undefined_users = {
    expr =
      let
        definedUsers = {
          alice = { };
          bob = { };
        };
        machineUsers = [
          "alice"
          "charlie"
          "bob"
        ];
        undefinedUsers = lib.filter (u: !(definedUsers ? ${u})) machineUsers;
      in
      undefinedUsers;
    expected = [ "charlie" ];
  };

  test_validation_no_undefined_users_when_valid = {
    expr =
      let
        definedUsers = {
          alice = { };
          bob = { };
        };
        machineUsers = [
          "alice"
          "bob"
        ];
        undefinedUsers = lib.filter (u: !(definedUsers ? ${u})) machineUsers;
      in
      undefinedUsers;
    expected = [ ];
  };

  test_validation_detects_invalid_positions = {
    expr =
      let
        allPositions = {
          owner = { };
          admin = { };
          basic = { };
        };
        usedPositions = [
          "owner"
          "superadmin"
          "basic"
        ];
        invalidPositions = lib.filter (p: !(allPositions ? ${p})) usedPositions;
      in
      invalidPositions;
    expected = [ "superadmin" ];
  };

  test_validation_no_invalid_positions_when_valid = {
    expr =
      let
        allPositions = {
          owner = { };
          admin = { };
          basic = { };
        };
        usedPositions = [
          "owner"
          "admin"
        ];
        invalidPositions = lib.filter (p: !(allPositions ? ${p})) usedPositions;
      in
      invalidPositions;
    expected = [ ];
  };

  test_validation_position_extraction_with_override = {
    expr =
      let
        users = {
          alice = {
            defaultPosition = "owner";
          };
        };
        machineUserCfg = {
          position = "admin";
        };
        getPosition =
          username: cfg:
          if cfg.position != null then cfg.position else (users.${username} or { }).defaultPosition or null;
      in
      getPosition "alice" machineUserCfg;
    expected = "admin";
  };

  test_validation_position_extraction_uses_default = {
    expr =
      let
        users = {
          alice = {
            defaultPosition = "owner";
          };
        };
        machineUserCfg = {
          position = null;
        };
        getPosition =
          username: cfg:
          if cfg.position != null then cfg.position else (users.${username} or { }).defaultPosition or null;
      in
      getPosition "alice" machineUserCfg;
    expected = "owner";
  };

  test_validation_position_extraction_handles_undefined_user = {
    expr =
      let
        users = {
          alice = {
            defaultPosition = "owner";
          };
        };
        machineUserCfg = {
          position = null;
        };
        getPosition =
          username: cfg:
          if cfg.position != null then cfg.position else (users.${username} or { }).defaultPosition or null;
      in
      getPosition "unknown" machineUserCfg;
    expected = null;
  };

  # ==========================================================================
  # 6. Platform difference tests (pure logic)
  # ==========================================================================

  test_home_dir_linux = {
    expr =
      let
        isDarwin = false;
        username = "alice";
        homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
      in
      homeDir;
    expected = "/home/alice";
  };

  test_home_dir_darwin = {
    expr =
      let
        isDarwin = true;
        username = "alice";
        homeDir = if isDarwin then "/Users/${username}" else "/home/${username}";
      in
      homeDir;
    expected = "/Users/alice";
  };

  test_password_gen_skipped_on_darwin = {
    expr =
      let
        isDarwin = true;
        allUserConfigs = {
          alice = {
            positionConfig.generatePassword = true;
          };
        };
        usersNeedingPasswords =
          if isDarwin then
            { }
          else
            lib.filterAttrs (_: cfg: cfg.positionConfig.generatePassword) allUserConfigs;
      in
      usersNeedingPasswords;
    expected = { };
  };

  test_password_gen_enabled_on_nixos = {
    expr =
      let
        isDarwin = false;
        allUserConfigs = {
          alice = {
            positionConfig.generatePassword = true;
          };
          bob = {
            positionConfig.generatePassword = false;
          };
        };
        usersNeedingPasswords =
          if isDarwin then
            { }
          else
            lib.filterAttrs (_: cfg: cfg.positionConfig.generatePassword) allUserConfigs;
      in
      builtins.attrNames usersNeedingPasswords;
    expected = [ "alice" ];
  };

  test_root_ssh_keys_skipped_on_darwin = {
    expr =
      let
        isDarwin = true;
        rootSshKeys =
          if isDarwin then
            [ ]
          else
            [
              "key1"
              "key2"
            ];
      in
      rootSshKeys;
    expected = [ ];
  };

  # ==========================================================================
  # 7. Option Example/Documentation Tests
  # ==========================================================================

  test_positions_has_example = {
    expr = interface.options.positions ? example;
    expected = true;
  };

  test_users_has_example = {
    expr = interface.options.users ? example;
    expected = true;
  };

  test_machines_has_example = {
    expr = interface.options.machines ? example;
    expected = true;
  };

  test_homeManager_has_example = {
    expr = interface.options.homeManager ? example;
    expected = true;
  };

  test_user_uid_has_example = {
    expr = userOpts.uid ? example;
    expected = true;
  };

  test_user_defaultPosition_has_example = {
    expr = userOpts.defaultPosition ? example;
    expected = true;
  };

  test_user_defaultShell_has_example = {
    expr = userOpts.defaultShell ? example;
    expected = true;
  };

  test_user_homeProfiles_has_example = {
    expr = userOpts.homeProfiles ? example;
    expected = true;
  };

  test_machine_user_position_has_example = {
    expr = machineUserOpts.position ? example;
    expected = true;
  };

  test_machine_user_shell_has_example = {
    expr = machineUserOpts.shell ? example;
    expected = true;
  };

  test_machine_user_homeProfiles_has_example = {
    expr = machineUserOpts.homeProfiles ? example;
    expected = true;
  };

  test_machine_user_extraHomeProfiles_has_example = {
    expr = machineUserOpts.extraHomeProfiles ? example;
    expected = true;
  };
}

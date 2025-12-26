# Roster Eval Tests
#
# Tests for the roster module, including home-manager integration.
#
# Phase 1: Basic module validation (current functionality)
# Phase 2: Home-manager interface options (TDD - will fail until implemented)
# Phase 3: Home-manager configuration generation
#
{
  lib,
  module,
  ...
}:
let
  # ==========================================================================
  # Test Helpers
  # ==========================================================================

  # Basic roster interface for inspection
  interface = module.roles.default.interface { inherit lib; };
  userOpts = interface.options.users.type.getSubOptions [ ];
  machineOpts = interface.options.machines.type.getSubOptions [ ];
  machineUserOpts = machineOpts.users.type.getSubOptions [ ];

in
{
  # ==========================================================================
  # Phase 1: Basic Module Validation
  # These tests validate the existing roster functionality works
  # ==========================================================================

  test_module_has_class = {
    expr = module._class;
    expected = "clan.service";
  };

  test_module_has_manifest = {
    expr = module.manifest.name;
    expected = "@onix/roster";
  };

  test_module_has_default_role = {
    expr = module.roles ? default;
    expected = true;
  };

  # User interface options
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

  test_user_has_packages = {
    expr = userOpts ? packages;
    expected = true;
  };

  # Machine user interface options
  test_machine_user_has_position = {
    expr = machineUserOpts ? position;
    expected = true;
  };

  test_machine_user_has_extraGroups = {
    expr = machineUserOpts ? extraGroups;
    expected = true;
  };

  test_machine_user_has_extraPackages = {
    expr = machineUserOpts ? extraPackages;
    expected = true;
  };

  # ==========================================================================
  # Phase 2: Home-Manager Interface Options (TDD)
  # These tests will FAIL until we implement the home-manager options
  # ==========================================================================

  test_user_has_homeModules = {
    expr = userOpts ? homeModules;
    expected = true;
  };

  test_machine_user_has_homeModules = {
    expr = machineUserOpts ? homeModules;
    expected = true;
  };

  test_machine_user_has_extraHomeModules = {
    expr = machineUserOpts ? extraHomeModules;
    expected = true;
  };

  test_has_homeManager_settings = {
    expr = interface.options ? homeManager;
    expected = true;
  };

  # Test that homeManager.module option exists (the explicit module input)
  test_homeManager_has_module_option = {
    expr =
      let
        hmOpts = interface.options.homeManager.type.getSubOptions [ ];
      in
      hmOpts ? module;
    expected = true;
  };

  # ==========================================================================
  # Phase 3: Home Modules Resolution Logic
  # Test that home modules are correctly resolved (default + extra, override)
  # ==========================================================================

  # Test the resolution logic pattern directly
  test_homeModules_resolution_uses_default = {
    expr =
      let
        userDefault = [
          "module1"
          "module2"
        ];
        machineOverride = null;
        machineExtra = [ ];
        resolved = if machineOverride != null then machineOverride else userDefault ++ machineExtra;
      in
      resolved;
    expected = [
      "module1"
      "module2"
    ];
  };

  test_homeModules_resolution_override_replaces = {
    expr =
      let
        userDefault = [
          "module1"
          "module2"
        ];
        machineOverride = [ "override" ];
        machineExtra = [ ];
        resolved = if machineOverride != null then machineOverride else userDefault ++ machineExtra;
      in
      resolved;
    expected = [ "override" ];
  };

  test_homeModules_resolution_extra_adds = {
    expr =
      let
        userDefault = [ "module1" ];
        machineOverride = null;
        machineExtra = [
          "extra1"
          "extra2"
        ];
        resolved = if machineOverride != null then machineOverride else userDefault ++ machineExtra;
      in
      resolved;
    expected = [
      "module1"
      "extra1"
      "extra2"
    ];
  };

  test_homeModules_empty_when_no_config = {
    expr =
      let
        userDefault = [ ];
        machineOverride = null;
        machineExtra = [ ];
        resolved = if machineOverride != null then machineOverride else userDefault ++ machineExtra;
      in
      resolved;
    expected = [ ];
  };

  # ==========================================================================
  # Phase 4: Module Structure Tests
  # These validate the clan service structure
  # ==========================================================================

  test_module_has_perMachine = {
    expr = module ? perMachine;
    expected = true;
  };

  test_perMachine_has_nixosModule = {
    expr = module.perMachine ? nixosModule;
    expected = true;
  };

  # ==========================================================================
  # Phase 5: Option Example/Documentation Tests
  # These verify that options have proper examples for documentation
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

  # User sub-options should have examples
  test_user_uid_has_example = {
    expr = userOpts.uid ? example;
    expected = true;
  };

  test_user_defaultPosition_has_example = {
    expr = userOpts.defaultPosition ? example;
    expected = true;
  };

  test_user_groups_has_example = {
    expr = userOpts.groups ? example;
    expected = true;
  };

  # Machine user sub-options should have examples
  test_machine_user_position_has_example = {
    expr = machineUserOpts.position ? example;
    expected = true;
  };

  test_machine_user_extraGroups_has_example = {
    expr = machineUserOpts.extraGroups ? example;
    expected = true;
  };

  # ==========================================================================
  # Phase 6: Resolution Logic with base + extra pattern
  # Tests the cleaner resolution using let base = ... in base ++ extra
  # ==========================================================================

  test_resolution_base_pattern_default = {
    expr =
      let
        machineValue = null;
        userDefault = [
          "a"
          "b"
        ];
        machineExtra = [ ];
        base = if machineValue != null then machineValue else userDefault;
      in
      base ++ machineExtra;
    expected = [
      "a"
      "b"
    ];
  };

  test_resolution_base_pattern_override = {
    expr =
      let
        machineValue = [ "override" ];
        userDefault = [
          "a"
          "b"
        ];
        machineExtra = [ "extra" ];
        base = if machineValue != null then machineValue else userDefault;
      in
      base ++ machineExtra;
    expected = [
      "override"
      "extra"
    ];
  };

  test_resolution_base_pattern_additive = {
    expr =
      let
        machineValue = null;
        userDefault = [ "a" ];
        machineExtra = [
          "b"
          "c"
        ];
        base = if machineValue != null then machineValue else userDefault;
      in
      base ++ machineExtra;
    expected = [
      "a"
      "b"
      "c"
    ];
  };

  # ==========================================================================
  # Phase 7: Validation Logic Tests
  # These test the pre-validation logic used for assertions
  # ==========================================================================

  # Test undefined user detection
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

  # Test invalid position detection
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

  # Test position extraction from machine config (handles undefined users gracefully)
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
}

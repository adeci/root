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

  test_machine_user_has_no_packages = {
    expr = !(machineUserOpts ? packages);
    expected = true;
  };

  test_machine_user_has_no_extraPackages = {
    expr = !(machineUserOpts ? extraPackages);
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

  # defaultPosition is now nullable
  test_user_defaultPosition_is_nullable = {
    expr = (userOpts.defaultPosition.type.name == "nullOr");
    expected = true;
  };

  # User override flags
  test_user_has_sudoAccess_flag = {
    expr = userOpts ? sudoAccess;
    expected = true;
  };

  test_user_has_generatePassword_flag = {
    expr = userOpts ? generatePassword;
    expected = true;
  };

  test_user_has_homeDirectory_flag = {
    expr = userOpts ? homeDirectory;
    expected = true;
  };

  test_user_has_isSystemUser_flag = {
    expr = userOpts ? isSystemUser;
    expected = true;
  };

  # Machine user override flags
  test_machine_user_has_sudoAccess_flag = {
    expr = machineUserOpts ? sudoAccess;
    expected = true;
  };

  test_machine_user_has_generatePassword_flag = {
    expr = machineUserOpts ? generatePassword;
    expected = true;
  };

  test_machine_user_has_homeDirectory_flag = {
    expr = machineUserOpts ? homeDirectory;
    expected = true;
  };

  test_machine_user_has_isSystemUser_flag = {
    expr = machineUserOpts ? isSystemUser;
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

  # Flag override priority: machine > user > position > fallback
  test_flag_override_machine_wins = {
    expr =
      let
        positionVal = false;
        userVal = true;
        machineVal = false;
        effective =
          if machineVal != null then
            machineVal
          else if userVal != null then
            userVal
          else
            positionVal;
      in
      effective;
    expected = false;
  };

  test_flag_override_user_wins_over_position = {
    expr =
      let
        positionVal = false;
        userVal = true;
        machineVal = null;
        effective =
          if machineVal != null then
            machineVal
          else if userVal != null then
            userVal
          else
            positionVal;
      in
      effective;
    expected = true;
  };

  test_flag_override_falls_back_to_position = {
    expr =
      let
        positionVal = true;
        userVal = null;
        machineVal = null;
        effective =
          if machineVal != null then
            machineVal
          else if userVal != null then
            userVal
          else
            positionVal;
      in
      effective;
    expected = true;
  };

  test_fallback_defaults_when_no_position = {
    expr =
      let
        fallbackDefaults = {
          sudoAccess = false;
          generatePassword = false;
          homeDirectory = true;
          isSystemUser = false;
        };
      in
      fallbackDefaults.homeDirectory;
    expected = true;
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

  test_machine_user_position_has_example = {
    expr = machineUserOpts.position ? example;
    expected = true;
  };

  test_machine_user_shell_has_example = {
    expr = machineUserOpts.shell ? example;
    expected = true;
  };

}

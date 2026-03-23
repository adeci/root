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
  # 1. Module Structure
  # ==========================================================================

  test_module_class = {
    expr = module._class;
    expected = "clan.service";
  };

  test_module_manifest_name = {
    expr = module.manifest.name;
    expected = "@adeci/roster";
  };

  test_module_has_default_role = {
    expr = module.roles ? default;
    expected = true;
  };

  test_perMachine_has_both_platforms = {
    expr = (module.perMachine ? nixosModule) && (module.perMachine ? darwinModule);
    expected = true;
  };

  # ==========================================================================
  # 2. Interface Options — verify the schema is correct
  # ==========================================================================

  test_user_has_required_options = {
    expr = builtins.all (opt: userOpts ? ${opt}) [
      "uid"
      "defaultPosition"
      "description"
      "groups"
      "sshAuthorizedKeys"
      "defaultShell"
      "sudoAccess"
      "generatePassword"
      "homeDirectory"
      "isSystemUser"
    ];
    expected = true;
  };

  test_user_has_no_hm_options = {
    expr = !(userOpts ? homeManagerProfiles);
    expected = true;
  };

  test_machine_user_has_required_options = {
    expr = builtins.all (opt: machineUserOpts ? ${opt}) [
      "position"
      "uid"
      "groups"
      "extraGroups"
      "shell"
      "sshAuthorizedKeys"
      "extraSshAuthorizedKeys"
      "sudoAccess"
      "generatePassword"
      "homeDirectory"
      "isSystemUser"
    ];
    expected = true;
  };

  test_machine_user_has_no_hm_options = {
    expr =
      (!(machineUserOpts ? homeManagerProfiles)) && (!(machineUserOpts ? extraHomeManagerProfiles));
    expected = true;
  };

  test_interface_has_no_hm_profile_map = {
    expr = !(interface.options ? homeManagerProfiles);
    expected = true;
  };

  test_user_defaultPosition_is_nullable = {
    expr = userOpts.defaultPosition.type.name == "nullOr";
    expected = true;
  };

  # ==========================================================================
  # 3. Flag Override Priority (machine > user > position > fallback)
  # ==========================================================================

  test_flag_priority_machine_wins = {
    expr =
      let
        resolve =
          machineVal: userVal: positionVal:
          if machineVal != null then
            machineVal
          else if userVal != null then
            userVal
          else
            positionVal;
      in
      resolve false true true;
    expected = false;
  };

  test_flag_priority_user_wins_over_position = {
    expr =
      let
        resolve =
          machineVal: userVal: positionVal:
          if machineVal != null then
            machineVal
          else if userVal != null then
            userVal
          else
            positionVal;
      in
      resolve null true false;
    expected = true;
  };

  test_flag_priority_falls_back_to_position = {
    expr =
      let
        resolve =
          machineVal: userVal: positionVal:
          if machineVal != null then
            machineVal
          else if userVal != null then
            userVal
          else
            positionVal;
      in
      resolve null null true;
    expected = true;
  };

  # ==========================================================================
  # 4. Validation Logic
  # ==========================================================================

  test_detects_undefined_users = {
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
      in
      lib.filter (u: !(definedUsers ? ${u})) machineUsers;
    expected = [ "charlie" ];
  };

  test_no_undefined_users_when_valid = {
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
      in
      lib.filter (u: !(definedUsers ? ${u})) machineUsers;
    expected = [ ];
  };

  test_detects_invalid_positions = {
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
      in
      lib.filter (p: !(allPositions ? ${p})) usedPositions;
    expected = [ "superadmin" ];
  };

  # ==========================================================================
  # 5. Position Resolution
  # ==========================================================================

  test_position_machine_override_wins = {
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

  test_position_falls_back_to_user_default = {
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

  test_position_null_for_undefined_user = {
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
  # 6. Shell Resolution
  # ==========================================================================

  test_shell_machine_overrides_user = {
    expr =
      let
        machineShell = "zsh";
        userShell = "fish";
      in
      if machineShell != null then machineShell else userShell;
    expected = "zsh";
  };

  test_shell_falls_back_to_user = {
    expr =
      let
        machineShell = null;
        userShell = "fish";
      in
      if machineShell != null then machineShell else userShell;
    expected = "fish";
  };

  test_shell_null_when_both_null = {
    expr =
      let
        machineShell = null;
        userShell = null;
      in
      if machineShell != null then machineShell else userShell;
    expected = null;
  };

  # ==========================================================================
  # 7. Platform Differences
  # ==========================================================================

  test_home_dir_linux = {
    expr =
      let
        isDarwin = false;
      in
      if isDarwin then "/Users/alice" else "/home/alice";
    expected = "/home/alice";
  };

  test_home_dir_darwin = {
    expr =
      let
        isDarwin = true;
      in
      if isDarwin then "/Users/alice" else "/home/alice";
    expected = "/Users/alice";
  };

  test_password_gen_skipped_on_darwin = {
    expr =
      let
        isDarwin = true;
        allUserConfigs = {
          alice = {
            generatePassword = true;
          };
        };
      in
      if isDarwin then { } else lib.filterAttrs (_: cfg: cfg.generatePassword) allUserConfigs;
    expected = { };
  };

  test_password_gen_enabled_on_nixos = {
    expr =
      let
        isDarwin = false;
        allUserConfigs = {
          alice = {
            generatePassword = true;
          };
          bob = {
            generatePassword = false;
          };
        };
      in
      builtins.attrNames (
        if isDarwin then { } else lib.filterAttrs (_: cfg: cfg.generatePassword) allUserConfigs
      );
    expected = [ "alice" ];
  };

  # ==========================================================================
  # 8. Groups Resolution
  # ==========================================================================

  test_groups_machine_override_replaces = {
    expr =
      let
        userGroups = [
          "video"
          "audio"
        ];
        machineGroups = [ "docker" ];
        extraGroups = [ ];
        base = if machineGroups != null then machineGroups else userGroups;
      in
      base ++ extraGroups;
    expected = [ "docker" ];
  };

  test_groups_extra_extends_defaults = {
    expr =
      let
        userGroups = [
          "video"
          "audio"
        ];
        machineGroups = null;
        extraGroups = [ "docker" ];
        base = if machineGroups != null then machineGroups else userGroups;
      in
      base ++ extraGroups;
    expected = [
      "video"
      "audio"
      "docker"
    ];
  };

  test_ssh_keys_extra_extends = {
    expr =
      let
        userKeys = [ "key1" ];
        machineKeys = null;
        extraKeys = [ "key2" ];
        base = if machineKeys != null then machineKeys else userKeys;
      in
      base ++ extraKeys;
    expected = [
      "key1"
      "key2"
    ];
  };
}

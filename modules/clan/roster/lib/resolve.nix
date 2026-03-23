{
  lib,
  pkgs,
  settings,
  machine,
  isDarwin,
  defaultPositions,
  fallbackPositionConfig,
}:
let
  allPositions = defaultPositions // settings.positions;

  machineConfig = settings.machines.${machine.name} or { users = { }; };

  machineUserNames = builtins.attrNames machineConfig.users;

  undefinedUsers = lib.filter (u: !(settings.users ? ${u})) machineUserNames;

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

  allUserConfigs = lib.mapAttrs getUserConfig machineConfig.users;

  usersNeedingPasswords =
    if isDarwin then
      { }
    else
      lib.filterAttrs (_: cfg: cfg.effectiveFlags.generatePassword) allUserConfigs;

  rootSshKeys =
    if isDarwin then
      [ ]
    else
      lib.flatten (
        lib.mapAttrsToList (
          _: cfg: if cfg.effectiveFlags.sudoAccess then cfg.effectiveSshKeys else [ ]
        ) allUserConfigs
      );

  ownerUser = lib.findFirst (
    username:
    let
      cfg = allUserConfigs.${username};
    in
    cfg.effectivePosition == "owner"
  ) null (builtins.attrNames allUserConfigs);
in
{
  inherit
    allPositions
    machineConfig
    undefinedUsers
    invalidPositions
    allUserConfigs
    usersNeedingPasswords
    rootSshKeys
    ownerUser
    ;
}

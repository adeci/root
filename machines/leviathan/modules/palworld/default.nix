{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Deploys start inactive servers asynchronously; manual restart performs an update.
  defaultInstance = {
    enable = true;
    port = 8211;
    queryPort = 27015;
    community = false;
    publicAddress = null;
    publicPort = null;
    serverName = null;
    openFirewall = false;
    settings = { };
    extraArgs = [ ];
  };

  palworldInstances = import ./instances.nix;
  instances = lib.mapAttrs (_: instance: defaultInstance // instance) palworldInstances;
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) instances;
  disabledInstances = lib.filterAttrs (_: instance: !instance.enable) instances;
  instanceNames = lib.attrNames instances;
  enabledInstanceNames = lib.attrNames enabledInstances;
  disabledInstanceNames = lib.attrNames disabledInstances;

  stateDir = name: "/var/lib/palworld/${name}";
  serverDir = name: "${stateDir name}/server";
  defaultSettingsFile = name: "${serverDir name}/DefaultPalWorldSettings.ini";
  savedDir = name: "${serverDir name}/Pal/Saved";
  settingsFile = name: "${savedDir name}/Config/LinuxServer/PalWorldSettings.ini";
  generatorName = name: "palworld-${name}";
  systemctl = "${config.systemd.package}/bin/systemctl";
  publicPort = instance: if instance.publicPort == null then instance.port else instance.publicPort;

  mkArgs =
    instance:
    [
      "-port=${toString instance.port}"
      "-queryport=${toString instance.queryPort}"
    ]
    ++ lib.optionals instance.community [
      "-publiclobby"
      "-publicport=${toString (publicPort instance)}"
    ]
    ++ [
      "-useperfthreads"
      "-NoAsyncLoadingThread"
      "-UseMultithreadForDS"
    ]
    ++ instance.extraArgs;

  mkCommunitySetup =
    instance:
    if instance.community then
      let
        address = if instance.publicAddress == null then "" else instance.publicAddress;
      in
      ''
        publicAddress=${lib.escapeShellArg address}
        if ! publicIp="$(${pkgs.getent}/bin/getent ahostsv4 "$publicAddress" | ${pkgs.gawk}/bin/awk 'NR == 1 { print $1; exit }')"; then
          echo "failed to resolve Palworld public address: $publicAddress" >&2
          exit 1
        fi
        if [ -z "$publicIp" ]; then
          echo "failed to resolve Palworld public address: $publicAddress" >&2
          exit 1
        fi
        communityArgs=("-publicip=$publicIp")
      ''
    else
      ''
        publicIp=
        communityArgs=()
      '';

  mkSettings =
    name: instance:
    {
      ServerName = if instance.serverName == null then name else instance.serverName;
      PublicPort = publicPort instance;
    }
    // instance.settings;

  mkSettingsJson =
    name: instance:
    pkgs.writeText "palworld-${name}-settings.json" (builtins.toJSON (mkSettings name instance));

  # Palworld stores settings as one OptionSettings=(...) tuple, not normal INI keys.
  patchSettings = pkgs.writeScript "palworld-patch-settings" ''
    #!${pkgs.python3}/bin/python3
    ${builtins.readFile ./patch-settings.py}
  '';

  mkUpdateScript =
    name:
    pkgs.writeShellScript "palworld-${name}-update" ''
      set -euo pipefail
      mkdir -p ${lib.escapeShellArg (serverDir name)}
      exec ${pkgs.steamcmd}/bin/steamcmd \
        +force_install_dir ${lib.escapeShellArg (serverDir name)} \
        +login anonymous \
        +app_update 2394010 validate \
        +quit
    '';

  mkStartScript =
    name: instance:
    pkgs.writeShellScript "palworld-${name}-start" ''
      set -euo pipefail
      ${mkCommunitySetup instance}
      install -D -m 0600 \
        ${lib.escapeShellArg (defaultSettingsFile name)} \
        ${lib.escapeShellArg (settingsFile name)}
      ${patchSettings} \
        ${lib.escapeShellArg (settingsFile name)} \
        ${mkSettingsJson name instance} \
        "$CREDENTIALS_DIRECTORY/admin-password" \
        "$CREDENTIALS_DIRECTORY/server-password" \
        "$publicIp"
      exec ${pkgs.steam-run}/bin/steam-run \
        ${lib.escapeShellArg "${serverDir name}/PalServer.sh"} \
        ${lib.escapeShellArgs (mkArgs instance)} \
        "''${communityArgs[@]}"
    '';

  mkService =
    name: instance:
    let
      vars = config.clan.core.vars.generators.${generatorName name};
    in
    {
      description = "Palworld dedicated server (${name})";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      restartIfChanged = false;
      stopIfChanged = false;

      path = [
        pkgs.steamcmd
        pkgs.steam-run
      ];

      environment = {
        HOME = stateDir name;
        LD_LIBRARY_PATH = "${serverDir name}/linux64";
      };

      serviceConfig = {
        Type = "simple";
        User = "palworld";
        Group = "palworld";
        WorkingDirectory = stateDir name;
        LoadCredential = [
          "admin-password:${vars.files.admin-password.path}"
          "server-password:${vars.files.server-password.path}"
        ];
        ExecStartPre = mkUpdateScript name;
        ExecStart = mkStartScript name instance;
        Restart = "on-failure";
        RestartSec = "30s";
        TimeoutStartSec = "30min";
        KillSignal = "SIGINT";
        SuccessExitStatus = [
          0
          130
          143
        ];

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ (stateDir name) ];
      };
    };

  mkTmpfilesRules = name: _instance: [
    "d ${stateDir name} 0750 palworld palworld - -"
    "d ${serverDir name} 0750 palworld palworld - -"
    "d ${savedDir name} 0750 palworld palworld - -"
  ];

  mkVarsGenerator =
    name: _instance:
    lib.nameValuePair (generatorName name) {
      files.admin-password.secret = true;
      files.server-password.secret = true;
      prompts.server-password = {
        description = "Palworld ${name} join password";
        type = "hidden";
        persist = true;
      };
      runtimeInputs = [ pkgs.pwgen ];
      script = ''
        pwgen -s 32 1 | tr -d '\n' > "$out/admin-password"
        cat "$prompts/server-password" > "$out/server-password"
      '';
    };
in
{
  assertions = import ./validation.nix { inherit lib instances enabledInstances; };

  clan.core.vars.generators = lib.mapAttrs' mkVarsGenerator instances;
  clan.core.state.palworld.folders = map savedDir instanceNames;

  users.groups.palworld = { };

  users.users.palworld = {
    isSystemUser = true;
    group = "palworld";
    home = "/var/lib/palworld";
    createHome = false;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/palworld 0750 palworld palworld - -"
  ]
  ++ lib.flatten (lib.mapAttrsToList mkTmpfilesRules instances);

  systemd.services = lib.mapAttrs' (
    name: instance: lib.nameValuePair "palworld-${name}" (mkService name instance)
  ) enabledInstances;

  system.activationScripts.managePalworld =
    lib.stringAfter
      [
        "etc"
        "setupSecrets"
      ]
      ''
        ${systemctl} daemon-reload
        ${lib.concatMapStringsSep "\n" (name: ''
          ${systemctl} stop --no-block palworld-${name}.service 2>/dev/null || true
        '') disabledInstanceNames}
        ${lib.concatMapStringsSep "\n" (name: ''
          if ! ${systemctl} is-active --quiet palworld-${name}.service; then
            ${systemctl} start --no-block palworld-${name}.service
          fi
        '') enabledInstanceNames}
      '';

  networking.firewall.allowedUDPPorts = lib.concatMap (
    instance:
    lib.optional instance.openFirewall instance.port
    ++ lib.optionals (instance.openFirewall && instance.community) [ instance.queryPort ]
  ) (lib.attrValues enabledInstances);
}

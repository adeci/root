{
  config,
  lib,
  pkgs,
  ...
}:
let
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

  instances = lib.mapAttrs (_: instance: defaultInstance // instance) (import ./instances.nix);
  enabledInstances = lib.filterAttrs (_: instance: instance.enable) instances;
  instanceNames = lib.attrNames instances;

  stateDir = name: "/var/lib/palworld/${name}";
  serverDir = name: "${stateDir name}/server";
  savedDir = name: "${serverDir name}/Pal/Saved";
  generatorName = name: "palworld-${name}";
  publicPort = instance: if instance.publicPort == null then instance.port else instance.publicPort;

  serverArgs =
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

  settingsJson =
    name: instance:
    pkgs.writeText "palworld-${name}-settings.json" (
      builtins.toJSON (
        {
          ServerName = if instance.serverName == null then name else instance.serverName;
          PublicPort = publicPort instance;
        }
        // instance.settings
      )
    );

  start = pkgs.writeShellApplication {
    name = "palworld-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.getent
      pkgs.python3
      pkgs.steam-run
      pkgs.steamcmd
    ];
    text = builtins.readFile ./start.sh;
  };

  service =
    name: instance:
    let
      passwords = config.clan.core.vars.generators.${generatorName name}.files;
    in
    {
      description = "Palworld dedicated server (${name})";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      # Deploys start inactive servers asynchronously; manual restart performs an update.
      restartIfChanged = false;
      stopIfChanged = false;

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
          "admin-password:${passwords.admin-password.path}"
          "server-password:${passwords.server-password.path}"
        ];
        # Updates the server first, here rather than in ExecStartPre so deploys don't wait on steamcmd.
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe start)
            (serverDir name)
            (settingsJson name instance)
            "${./patch-settings.py}"
            (if instance.community then instance.publicAddress else "")
          ]
          ++ serverArgs instance
        );
        Restart = "on-failure";
        RestartSec = "30s";
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

  tmpfilesRules = name: _instance: [
    "d ${stateDir name} 0750 palworld palworld - -"
    "d ${serverDir name} 0750 palworld palworld - -"
    "d ${savedDir name} 0750 palworld palworld - -"
  ];

  varsGenerator =
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

  clan.core.vars.generators = lib.mapAttrs' varsGenerator instances;
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
  ++ lib.flatten (lib.mapAttrsToList tmpfilesRules instances);

  systemd.services = lib.mapAttrs' (
    name: instance: lib.nameValuePair "palworld-${name}" (service name instance)
  ) enabledInstances;

  networking.firewall.allowedUDPPorts = lib.concatMap (
    instance:
    lib.optional instance.openFirewall instance.port
    ++ lib.optionals (instance.openFirewall && instance.community) [ instance.queryPort ]
  ) (lib.attrValues enabledInstances);
}

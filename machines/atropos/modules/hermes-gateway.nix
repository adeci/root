{ inputs, pkgs, ... }:
let
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  hermesPackage = llm-agents.hermes-agent.overridePythonAttrs (old: {
    # llm-agents hermes-agent 2026.5.16 pins psutil==7.2.2, while this
    # nixpkgs currently packages 7.2.1. Runtime API use is compatible; relax
    # the wheel metadata until llm-agents/nixpkgs converge.
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "psutil" ];
  });

  user = "alex";
  group = "users";
  userHome = "/home/${user}";
  hermesHome = "${userHome}/.hermes";

  extraPackages = [
    llm-agents.openspec
    pkgs.codex
    pkgs.curl
    pkgs.fd
    pkgs.git
    pkgs.jq
    pkgs.nix
    pkgs.nodejs_22
    pkgs.ripgrep
  ];

  configFile = pkgs.writeText "hermes-config.yaml" (
    builtins.toJSON {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };

      terminal = {
        backend = "local";
        cwd = ".";
        timeout = 180;
      };

      discord = {
        require_mention = true;
        auto_thread = true;
        thread_require_mention = false;
        reactions = true;
        history_backfill = true;
      };

      display = {
        tool_progress = "all";
        tool_progress_command = true;
      };

      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };

      group_sessions_per_user = true;
    }
  );
in
{
  environment.systemPackages = [
    hermesPackage
    pkgs.codex
  ];

  systemd.tmpfiles.rules = [
    "d ${hermesHome} 0700 ${user} ${group} - -"
    "d ${hermesHome}/cron 0700 ${user} ${group} - -"
    "d ${hermesHome}/logs 0700 ${user} ${group} - -"
    "d ${hermesHome}/memories 0700 ${user} ${group} - -"
    "d ${hermesHome}/plugins 0700 ${user} ${group} - -"
    "d ${hermesHome}/sessions 0700 ${user} ${group} - -"
  ];

  system.activationScripts.hermes-gateway-setup = ''
    install -d -o ${user} -g ${group} -m 0700 ${hermesHome}

    if [ ! -f ${hermesHome}/config.yaml ]; then
      install -o ${user} -g ${group} -m 0600 ${configFile} ${hermesHome}/config.yaml
    fi
    touch ${hermesHome}/.managed
    chown ${user}:${group} ${hermesHome}/.managed
    chmod 0644 ${hermesHome}/.managed
  '';

  systemd.services.hermes-agent = {
    description = "Hermes Agent Gateway";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      HOME = userHome;
      HERMES_ACCEPT_HOOKS = "1";
      HERMES_HOME = hermesHome;
      HERMES_MANAGED = "true";
      HERMES_REDACT_SECRETS = "true";
    };

    serviceConfig = {
      User = user;
      Group = group;
      WorkingDirectory = userHome;
      ExecStart = "${hermesPackage}/bin/hermes --accept-hooks gateway run";
      Restart = "always";
      RestartSec = 5;
      UMask = "0077";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ userHome ];
      PrivateTmp = true;
    };

    path = [
      hermesPackage
      pkgs.bash
      pkgs.coreutils
    ]
    ++ extraPackages;
  };
}

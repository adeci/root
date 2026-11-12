{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.resources) homelan;
  cfg = config.services.paperless;
  ai = config.paperlessAi;

  paperlessHost = "paperless.decio.us";
  tailnetCidr = self.resources.tailscale.cidr;

  dataDir = "/srv/paperless";
  workflows = ./paperless-workflows.py;
  # The workflows are applied again only when this changes, so edits made in the UI stay until then.
  workflowsDeclaration = "${workflows} ai=${lib.boolToString ai.enable}";
in
{
  options.paperlessAi = {
    enable = lib.mkEnableOption "AI filing: title, tags, correspondent, type and date from a language model";

    endpoint = lib.mkOption {
      type = lib.types.str;
      example = "http://leviathan:8080/v1";
      description = "Base URL of an OpenAI-compatible API that needs no API key.";
    };

    model = lib.mkOption {
      type = lib.types.str;
      description = "Model to ask; it must support tool calls.";
    };
  };

  config = {
    clan.core.state.paperless.folders = [ dataDir ];

    clan.core.postgresql.enable = true;
    clan.core.postgresql.databases.paperless = {
      create.enable = false;
      restore.stopOnRestore = [
        "paperless-consumer"
        "paperless-scheduler"
        "paperless-task-queue"
        "paperless-web"
      ];
    };

    clan.core.vars.generators.paperless = {
      files = {
        admin-password.secret = true;
      };

      runtimeInputs = [ pkgs.pwgen ];

      script = ''
        pwgen -s 32 1 | tr -d '\n' > "$out/admin-password"
      '';
    };

    services.paperless = {
      enable = true;
      address = "127.0.0.1";
      port = 28981;
      domain = paperlessHost;
      configureNginx = true;

      inherit dataDir;

      passwordFile = config.clan.core.vars.generators.paperless.files.admin-password.path;
      database.createLocally = true;

      exporter.enable = true;

      # OCR defaults (English, rotate, deskew, clean, PDF/A) fit; setting a language would rebuild Paperless from source.
      settings = {
        PAPERLESS_ADMIN_USER = config.system.primaryUser;
        PAPERLESS_DATE_ORDER = "MDY";
        PAPERLESS_CONSUMER_RECURSIVE = true;
        PAPERLESS_CONSUMER_DELETE_DUPLICATES = true;
      }
      // lib.optionalAttrs ai.enable {
        PAPERLESS_AI_ENABLED = true;
        PAPERLESS_AI_LLM_BACKEND = "openai-like";
        PAPERLESS_AI_LLM_ENDPOINT = ai.endpoint;
        PAPERLESS_AI_LLM_MODEL = ai.model;
        # A second worker keeps a slow AI request from holding up the next scan.
        PAPERLESS_TASK_WORKERS = 2;
      };
    };

    systemd.services.paperless-workflows = {
      description = "Paperless tags and workflows";
      wantedBy = [ "paperless-scheduler.service" ];
      requires = [ "paperless-scheduler.service" ];
      after = [ "paperless-scheduler.service" ];
      path = [ cfg.manage ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = cfg.user;
      };
      script = ''
        applied=${dataDir}/workflows-applied
        if [[ "$(cat "$applied" 2>/dev/null)" != ${lib.escapeShellArg workflowsDeclaration} ]]; then
          paperless-manage shell --no-imports --command "$(cat ${workflows})"
          echo ${lib.escapeShellArg workflowsDeclaration} > "$applied"
        fi
      '';
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      serverTokens = false;

      virtualHosts.${paperlessHost} = {
        useACMEHost = "decio.us";
        extraConfig = ''
          allow ${homelan.vlans.trusted.cidr};
          allow ${tailnetCidr};
          deny all;
          client_max_body_size 512M;
        '';
      };
    };
  };
}

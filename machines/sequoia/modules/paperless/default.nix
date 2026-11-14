{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory) lan tailnet;

  domain = "paperless.decio.us";
  dataDir = "/srv/paperless";

  workflows = ./paperless-workflows.py;
  # The workflows are applied again only when this changes, so edits made in the UI stay until then.
  workflowsDeclaration = "${workflows} ai=${lib.boolToString config.paperlessAi.enable}";

  applyWorkflows = pkgs.writeShellApplication {
    name = "paperless-workflows";
    runtimeInputs = [
      pkgs.coreutils
      config.services.paperless.manage
    ];
    text = builtins.readFile ./paperless-workflows.sh;
  };
in
{
  imports = [ self.modules.nixos.primary-user ];

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
      inherit domain;
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
      // lib.optionalAttrs config.paperlessAi.enable {
        PAPERLESS_AI_ENABLED = true;
        PAPERLESS_AI_LLM_BACKEND = "openai-like";
        PAPERLESS_AI_LLM_ENDPOINT = config.paperlessAi.endpoint;
        PAPERLESS_AI_LLM_MODEL = config.paperlessAi.model;
        # A second worker keeps a slow AI request from holding up the next scan.
        PAPERLESS_TASK_WORKERS = 2;
      };
    };

    systemd.services.paperless-workflows = {
      description = "Paperless tags and workflows";
      wantedBy = [ "paperless-scheduler.service" ];
      requires = [ "paperless-scheduler.service" ];
      after = [ "paperless-scheduler.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.services.paperless.user;
        ExecStart = "${lib.getExe applyWorkflows} ${dataDir}/workflows-applied ${lib.escapeShellArg workflowsDeclaration} ${workflows}";
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      serverTokens = false;

      virtualHosts.${domain} = {
        useACMEHost = "decio.us";
        extraConfig = ''
          allow ${lan.vlans.trusted.cidr};
          allow ${tailnet.cidr};
          deny all;
          client_max_body_size 512M;
        '';
      };
    };
  };
}

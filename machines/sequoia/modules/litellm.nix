{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  litellmPort = 4000;
  litellmTunnelPort = 8391;
  litellmAdminPort = 8392;
  stateDir = "/var/lib/litellm";

  litellmEnvFile = config.clan.core.vars.generators.litellm.files."litellm.env".path;
  databaseEnvFile = config.clan.core.vars.generators.litellm-database.files."database.env".path;

  yaml = pkgs.formats.yaml { };

  litellmPackage = self.inputs.litellm-nix.packages.${pkgs.stdenv.hostPlatform.system}."litellm-nix";
  inherit (self.resources.llm) models weights;
  leviathanLlmBaseUrl = "http://leviathan.cymric-daggertooth.ts.net:11435/v1";

  modelCostMap = builtins.fromJSON (
    builtins.readFile "${litellmPackage.pythonPackage.src}/litellm/model_prices_and_context_window_backup.json"
  );

  pricingFromLiteLLM =
    model:
    let
      source = modelCostMap.${model.pricing.model};
    in
    builtins.listToAttrs (
      builtins.map (name: {
        inherit name;
        value = source.${name};
      }) model.pricing.fields
    );

  contextWindowFor =
    model:
    model.contextWindow or (
      if model.backend.type == "local-gguf" then
        weights.${model.backend.weight}.nativeContextWindow
      else
        null
    );

  modelInfo =
    model:
    let
      contextWindow = contextWindowFor model;
      pricing =
        if (model.pricing.source or null) == "litellm" then
          pricingFromLiteLLM model
        else
          {
            input_cost_per_token = 0;
            output_cost_per_token = 0;
          };
    in
    pricing
    // {
      mode = model.mode or "chat";
    }
    // lib.optionalAttrs (contextWindow != null) {
      max_input_tokens = contextWindow;
      max_tokens = contextWindow;
    }
    // lib.optionalAttrs (model ? maxTokens) {
      max_output_tokens = model.maxTokens;
    };

  litellmParams =
    name: model:
    if model.backend.type == "litellm" then
      { inherit (model.backend) model; }
    else if model.backend.type == "local-gguf" then
      {
        model = "openai/${name}";
        api_base = leviathanLlmBaseUrl;
        api_key = "local";
      }
    else
      throw "unsupported LLM backend: ${model.backend.type}";

  modelName = name: model: if model.backend.type == "local-gguf" then "local/${name}" else name;

  mkLiteLLMModel = name: model: {
    model_name = modelName name model;
    model_info = modelInfo model;
    litellm_params = litellmParams name model;
  };

  litellmConfig = yaml.generate "litellm-config.yaml" {
    model_list = lib.mapAttrsToList mkLiteLLMModel models;

    litellm_settings = {
      drop_params = true;
      request_timeout = 600;
      callbacks = [ "prometheus" ];
      prometheus_initialize_budget_metrics = true;
    };

    general_settings = {
      master_key = "os.environ/LITELLM_MASTER_KEY";
      database_url = "os.environ/DATABASE_URL";
      store_model_in_db = true;
      store_prompts_in_spend_logs = true;
    };
  };
in
{
  imports = [ self.inputs.litellm-nix.nixosModules.default ];

  services.litellm-nix = {
    enable = true;
    configFile = litellmConfig;
    inherit databaseEnvFile stateDir;
    port = litellmPort;
    requireChatgptAuth = true;
    enableChatgptLogin = true;
    enableCodexUsage = true;
    envFiles = [ litellmEnvFile ];
  };

  systemd.services.litellm-prune-prompt-logs = {
    description = "Prune LiteLLM stored prompt/response bodies";
    after = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
    };
    script = # bash
      ''
        ${config.services.postgresql.package}/bin/psql -d litellm -v ON_ERROR_STOP=1 <<'SQL'
          UPDATE "LiteLLM_SpendLogs"
          SET
            messages = '{}'::jsonb,
            response = '{}'::jsonb,
            proxy_server_request = '{}'::jsonb
          WHERE "startTime" < now() - interval '180 days'
            AND (
              messages <> '{}'::jsonb
              OR response <> '{}'::jsonb
              OR proxy_server_request <> '{}'::jsonb
            );
        SQL
      '';
  };

  systemd.timers.litellm-prune-prompt-logs = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  # --- PostgreSQL (declarative via clan.core) ---

  clan.core.postgresql.enable = true;
  clan.core.postgresql.users.litellm = { };
  clan.core.postgresql.databases.litellm = {
    create.options.OWNER = "litellm";
    restore.stopOnRestore = [ "litellm" ];
  };

  # --- State ---

  clan.core.state.litellm.folders = [ stateDir ];

  # --- Secrets ---
  # LITELLM_SALT_KEY must stay stable; LiteLLM uses it to encrypt/decrypt
  # provider credentials stored in the database.

  clan.core.vars.generators.litellm = {
    files."litellm.env".secret = true;
    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];
    script = ''
      MASTER_KEY="sk-$(openssl rand -hex 32)"
      SALT_KEY="$(openssl rand -base64 32 | tr -d '\n')"

      {
        printf 'LITELLM_MASTER_KEY=%s\n' "$MASTER_KEY"
        printf 'LITELLM_SALT_KEY=%s\n' "$SALT_KEY"
      } > "$out/litellm.env"
    '';
  };

  clan.core.vars.generators.litellm-database = {
    files."database.env".secret = true;
    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];
    script = ''
      PASSWORD="$(openssl rand -hex 32)"

      {
        printf 'LITELLM_DATABASE_PASSWORD=%s\n' "$PASSWORD"
        printf 'DATABASE_URL=postgresql://litellm:%s@127.0.0.1:5432/litellm\n' "$PASSWORD"
      } > "$out/database.env"
    '';
  };

  # --- Network ---

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ litellmAdminPort ];

  # --- Nginx ---

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    serverTokens = false;

    virtualHosts."llm.decio.us" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = litellmTunnelPort;
        }
      ];

      extraConfig = ''
        client_max_body_size 64M;
      '';

      locations."/v1/" = {
        proxyPass = "http://127.0.0.1:${toString litellmPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 3600s;
        '';
      };

      # Public Cloudflare tunnel terminates here. Keep this host API-only:
      # do not proxy root/admin/key routes from this vhost.
      locations."/".extraConfig = ''
        return 404;
      '';
    };

    virtualHosts."litellm-admin.localhost" = {
      serverAliases = [
        "sequoia"
        "sequoia.cymric-daggertooth.ts.net"
      ];

      listen = [
        {
          addr = "0.0.0.0";
          port = litellmAdminPort;
        }
      ];

      extraConfig = ''
        allow 127.0.0.1;
        allow 100.64.0.0/10;
        deny all;
        client_max_body_size 64M;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString litellmPort}";
        proxyWebsockets = true;
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          proxy_set_header X-Forwarded-Port $server_port;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_buffering off;
          proxy_read_timeout 3600s;
        '';
      };
    };
  };
}

{
  config,
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
  modelCostMap = builtins.fromJSON (
    builtins.readFile "${litellmPackage.pythonPackage.src}/litellm/model_prices_and_context_window_backup.json"
  );
  gpt55Pricing =
    let
      source = modelCostMap."gpt-5.5";
      fields = [
        "max_input_tokens"
        "max_output_tokens"
        "max_tokens"
        "input_cost_per_token"
        "input_cost_per_token_above_272k_tokens"
        "output_cost_per_token"
        "output_cost_per_token_above_272k_tokens"
        "cache_read_input_token_cost"
        "cache_read_input_token_cost_above_272k_tokens"
      ];
    in
    builtins.listToAttrs (
      builtins.map (name: {
        inherit name;
        value = source.${name};
      }) fields
    );

  litellmConfig = yaml.generate "litellm-config.yaml" {
    model_list = [
      {
        model_name = "gpt-5.5";
        model_info = gpt55Pricing // {
          mode = "responses";
        };
        litellm_params.model = "chatgpt/gpt-5.5";
      }
    ];

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

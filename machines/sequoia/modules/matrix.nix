{
  config,
  pkgs,
  ...
}:
let
  serverName = "decio.us";
  matrixDomain = "matrix.decio.us";
  synapsePort = 8008;
in
{

  # --- PostgreSQL ---

  services.postgresql = {
    enable = true;
    # Synapse requires PostgreSQL with LC_COLLATE='C'. NixOS's ensureDatabases
    # creates databases with the system locale (en_US.UTF-8), which Synapse
    # rejects. No declarative fix exists upstream (nixpkgs#285688).
    #
    # The database must be created manually once per machine:
    #   sudo -u postgres psql -c "
    #     CREATE DATABASE \"matrix-synapse\"
    #       OWNER \"matrix-synapse\"
    #       ENCODING 'UTF8'
    #       LC_COLLATE 'C'
    #       LC_CTYPE 'C'
    #       TEMPLATE template0;
    #   "
    #
    # The "matrix-synapse" user is created declaratively by ensureUsers below.
    # Ownership was set during CREATE DATABASE above.
    ensureUsers = [
      {
        name = "matrix-synapse";
      }
    ];
  };

  # --- Synapse ---

  services.matrix-synapse = {
    enable = true;

    extraConfigFiles = [
      config.clan.core.vars.generators.matrix-secrets.files."secrets.yaml".path
    ];

    settings = {
      server_name = serverName;
      public_baseurl = "https://${matrixDomain}";

      listeners = [
        {
          port = synapsePort;
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [
                "client"
                "federation"
              ];
              compress = true;
            }
          ];
        }
      ];

      database = {
        name = "psycopg2";
        args = {
          database = "matrix-synapse";
          user = "matrix-synapse";
          host = "/run/postgresql";
          cp_min = 5;
          cp_max = 10;
        };
      };

      # Media storage
      max_upload_size = "1G";
      url_preview_enabled = true;
      media_retention = {
        # Purge cached remote media after 30 days
        # (re-fetched on demand if the origin server is still up)
        remote_media_lifetime = "30d";
      };

      # Registration closed — use shared secret to create accounts
      enable_registration = false;

      # Federation
      trusted_key_servers = [
        {
          server_name = "matrix.org";
        }
      ];

      # Don't report stats to matrix.org
      report_stats = false;

      # Presence can be chatty on federated rooms
      presence.enabled = false;
    };
  };

  # --- Secrets ---
  # Generates registration_shared_secret, macaroon_secret_key, form_secret
  # and writes them as a YAML file Synapse loads via extraConfigFiles.

  clan.core.vars.generators.matrix-secrets = {
    files."secrets.yaml" = {
      secret = true;
      owner = "matrix-synapse";
      group = "matrix-synapse";
    };
    runtimeInputs = [ pkgs.openssl ];
    script = ''
      registration=$(openssl rand -base64 32 | tr -d '\n')
      macaroon=$(openssl rand -base64 32 | tr -d '\n')
      form=$(openssl rand -base64 32 | tr -d '\n')

      cat > "$out/secrets.yaml" <<EOF
      registration_shared_secret: "$registration"
      macaroon_secret_key: "$macaroon"
      form_secret: "$form"
      EOF
    '';
  };

  # --- .well-known delegation ---
  # Serves delegation JSON so federation resolves @alex:decio.us → matrix.decio.us.
  # Exposed via Cloudflare tunnel (decio.us → localhost:8748).
  # When decio.us gets a proper website, move these location blocks into that
  # site's config and remove this standalone vhost.

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    serverTokens = false;

    # Suppress default nginx welcome page
    virtualHosts."_default" = {
      default = true;
      locations."/".extraConfig = ''
        default_type text/plain;
        return 200 "nothing here, yet :)";
      '';
    };

    # Reverse proxy for Synapse — only expose /_matrix, block /_synapse admin API
    virtualHosts."matrix" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = 8448;
        }
      ];
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 600;
        client_max_body_size 1G;
      '';
      locations."/_matrix".proxyPass = "http://127.0.0.1:${toString synapsePort}";
      locations."/".extraConfig = ''
        default_type text/plain;
        return 404;
      '';
    };

    # .well-known delegation for federation discovery
    virtualHosts."well-known-matrix" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = 8748;
        }
      ];
      locations."=/.well-known/matrix/server".extraConfig = ''
        add_header Content-Type application/json;
        return 200 '{"m.server":"${matrixDomain}:443"}';
      '';
      locations."=/.well-known/matrix/client".extraConfig = ''
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
        return 200 '{"m.homeserver": {"base_url": "https://${matrixDomain}"}}';
      '';
      locations."/".extraConfig = ''
        default_type text/plain;
        return 200 "nothing here, yet :)";
      '';
    };
  };

  # --- Media retention ---
  # remote_media_lifetime in settings handles cached remote media cleanup.
  # Local media (your uploads) is kept forever.

}

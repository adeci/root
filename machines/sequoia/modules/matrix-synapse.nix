{
  config,
  pkgs,
  lib,
  ...
}:
let
  serverName = "decio.us";
  matrixDomain = "matrix.decio.us";
  synapsePort = 8008;

  users = {
    alex = {
      name = "alex";
      admin = true;
    };
    watari = {
      name = "watari";
      admin = false;
    };
  };

  element-web =
    pkgs.runCommand "element-web-with-config"
      {
        nativeBuildInputs = [ pkgs.buildPackages.jq ];
      }
      ''
        cp -r ${pkgs.element-web} $out
        chmod -R u+w $out
        jq '."default_server_config"."m.homeserver" = { "base_url": "https://${matrixDomain}", "server_name": "${serverName}" }' \
          > $out/config.json < ${pkgs.element-web}/config.json
        ln -s $out/config.json $out/config.${matrixDomain}.json
      '';
in
{

  # --- PostgreSQL (declarative via clan.core) ---
  # Handles database creation with LC_COLLATE='C' and backup/restore state.

  clan.core.postgresql.enable = true;
  clan.core.postgresql.users.matrix-synapse = { };
  clan.core.postgresql.databases.matrix-synapse.create.options = {
    TEMPLATE = "template0";
    LC_COLLATE = "C";
    LC_CTYPE = "C";
    ENCODING = "UTF8";
    OWNER = "matrix-synapse";
  };
  clan.core.postgresql.databases.matrix-synapse.restore.stopOnRestore = [ "matrix-synapse" ];

  # --- Synapse ---

  services.matrix-synapse = {
    enable = true;

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
      # Keep all media forever (local and remote)

      # Registration closed — users provisioned declaratively below
      enable_registration = false;
      registration_shared_secret_path = "/run/synapse-registration-shared-secret";

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
  # Registration shared secret for user provisioning,
  # plus per-user passwords generated via xkcdpass.

  clan.core.vars.generators = {
    "matrix-synapse" = {
      files."synapse-registration_shared_secret" = { };
      runtimeInputs = with pkgs; [
        coreutils
        pwgen
      ];
      script = ''
        echo -n "$(pwgen -s 32 1)" > "$out"/synapse-registration_shared_secret
      '';
    };
  }
  // lib.mapAttrs' (
    _: user:
    lib.nameValuePair "matrix-password-${user.name}" {
      files."matrix-password-${user.name}" = { };
      runtimeInputs = with pkgs; [ xkcdpass ];
      script = ''
        xkcdpass -n 6 -d - > "$out"/${lib.escapeShellArg "matrix-password-${user.name}"}
      '';
    }
  ) users;

  # --- User provisioning ---
  # Waits for Synapse to be ready, then creates users with --exists-ok
  # so it's idempotent on subsequent boots.

  systemd.services.matrix-synapse =
    let
      usersScript = ''
        while ! ${pkgs.netcat}/bin/nc -z -v 127.0.0.1 ${toString synapsePort}; do
          if ! kill -0 "$MAINPID"; then exit 1; fi
          sleep 1;
        done
      ''
      + lib.concatMapStringsSep "\n" (user: ''
        /run/current-system/sw/bin/matrix-synapse-register_new_matrix_user \
          --exists-ok \
          --password-file ${
            config.clan.core.vars.generators."matrix-password-${user.name}".files."matrix-password-${user.name}".path
          } \
          --user "${user.name}" \
          ${if user.admin then "--admin" else "--no-admin"}
      '') (lib.attrValues users);
    in
    {
      path = [ pkgs.curl ];
      serviceConfig.ExecStartPre = lib.mkBefore [
        "+${pkgs.coreutils}/bin/install -o matrix-synapse -g matrix-synapse ${
          lib.escapeShellArg
            config.clan.core.vars.generators.matrix-synapse.files."synapse-registration_shared_secret".path
        } /run/synapse-registration-shared-secret"
      ];
      serviceConfig.ExecStartPost = [
        "+${pkgs.writeShellScript "matrix-synapse-create-users" usersScript}"
      ];
    };

  # --- Nginx ---
  # Tunnel-friendly: binds to localhost on custom ports.
  # Cloudflare tunnel routes:
  #   matrix.decio.us → localhost:8448
  #   decio.us        → localhost:8748

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

    # Matrix reverse proxy + Element Web client
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
      locations."/".root = element-web;
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

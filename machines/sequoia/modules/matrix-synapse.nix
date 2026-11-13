{
  config,
  pkgs,
  lib,
  self,
  ...
}:
let
  serverName = "decio.us";
  matrixDomain = "matrix.decio.us";
  synapsePort = 8008;
  tunnels = self.inventory.cloudflare.tunnels.sequoia;

  users = {
    alex.admin = true;
    watari.admin = false;
  };

  passwordFile =
    name:
    config.clan.core.vars.generators."matrix-password-${name}".files."matrix-password-${name}".path;

  waitForPort = pkgs.writeShellApplication {
    name = "matrix-synapse-wait-for-port";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.netcat
    ];
    text = builtins.readFile ./matrix-synapse-wait-for-port.sh;
  };

  registerUser =
    name: user:
    lib.concatStringsSep " " [
      "+/run/current-system/sw/bin/matrix-synapse-register_new_matrix_user"
      "--exists-ok"
      "--password-file ${passwordFile name}"
      "--user ${name}"
      (if user.admin then "--admin" else "--no-admin")
    ];

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

  clan.core.state.matrix-synapse.folders = [
    config.services.matrix-synapse.settings.media_store_path
  ];

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

      max_upload_size = "1G";
      url_preview_enabled = true;
      # No media_retention: local and remote media are kept forever.

      # Users are provisioned below through the shared secret.
      enable_registration = false;
      registration_shared_secret_path = "/run/synapse-registration-shared-secret";

      trusted_key_servers = [
        {
          server_name = "matrix.org";
        }
      ];

      report_stats = false;

      # Presence can be chatty on federated rooms
      presence.enabled = false;
    };
  };

  clan.core.vars.generators = {
    "matrix-synapse" = {
      files."synapse-registration_shared_secret" = { };
      runtimeInputs = [
        pkgs.coreutils
        pkgs.pwgen
      ];
      script = ''
        echo -n "$(pwgen -s 32 1)" > "$out"/synapse-registration_shared_secret
      '';
    };
  }
  // lib.mapAttrs' (
    name: _:
    lib.nameValuePair "matrix-password-${name}" {
      files."matrix-password-${name}" = { };
      runtimeInputs = [ pkgs.xkcdpass ];
      script = ''
        xkcdpass -n 6 -d - > "$out"/${lib.escapeShellArg "matrix-password-${name}"}
      '';
    }
  ) users;

  systemd.services.matrix-synapse.serviceConfig = {
    ExecStartPre = lib.mkBefore [
      "+${lib.getExe' pkgs.coreutils "install"} -o matrix-synapse -g matrix-synapse ${
        lib.escapeShellArg
          config.clan.core.vars.generators.matrix-synapse.files."synapse-registration_shared_secret".path
      } /run/synapse-registration-shared-secret"
    ];
    ExecStartPost = [
      "+${lib.getExe waitForPort} ${toString synapsePort}"
    ]
    ++ lib.mapAttrsToList registerUser users;
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    serverTokens = false;

    virtualHosts."_default" = {
      default = true;
      locations."/".extraConfig = ''
        default_type text/plain;
        return 200 "nothing here, yet :)";
      '';
    };

    virtualHosts."matrix" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = tunnels.${matrixDomain}.port;
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

    virtualHosts."well-known-matrix" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = tunnels.${serverName}.port;
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

}

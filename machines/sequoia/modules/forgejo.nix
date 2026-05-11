{
  config,
  pkgs,
  ...
}:
let
  forgejoPort = 3001;
  forgejoSshPort = 2222;
  forgejoTunnelPort = 8321;
in
{
  # Forgejo web is exposed through Cloudflare Tunnel at https://git.decio.us.
  # Git SSH uses Forgejo's built-in SSH server, reachable publicly via
  # conduit → Tailscale on git-ssh.decio.us:2222.

  # --- PostgreSQL (declarative via clan.core) ---

  clan.core.postgresql.enable = true;
  clan.core.postgresql.users.forgejo = { };
  clan.core.postgresql.databases.forgejo = {
    create.options.OWNER = "forgejo";
    restore.stopOnRestore = [ "forgejo" ];
  };

  # --- State ---

  clan.core.state.forgejo.folders = [ config.services.forgejo.stateDir ];

  # --- Forgejo ---

  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;

    lfs.enable = true;

    database = {
      type = "postgres";
      createDatabase = false;
      socket = "/run/postgresql";
      name = "forgejo";
      user = "forgejo";
    };

    settings = {
      DEFAULT.APP_NAME = "git.decio.us";

      server = {
        DOMAIN = "git.decio.us";
        ROOT_URL = "https://git.decio.us/";
        HTTP_ADDR = "127.0.0.1";
        HTTP_PORT = forgejoPort;

        DISABLE_SSH = false;
        START_SSH_SERVER = true;
        BUILTIN_SSH_SERVER_USER = "git";
        SSH_USER = "git";
        SSH_DOMAIN = "git-ssh.decio.us";
        SSH_PORT = forgejoSshPort;
        SSH_LISTEN_HOST = "0.0.0.0";
        SSH_LISTEN_PORT = forgejoSshPort;
      };

      service.DISABLE_REGISTRATION = true;
      session.COOKIE_SECURE = true;

      repository.DEFAULT_PRIVATE = "private";

      actions.ENABLED = true;
    };
  };

  # Make the admin CLI available for manual bootstrap/admin tasks.
  environment.systemPackages = [ config.services.forgejo.package ];

  # --- Network ---

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ forgejoSshPort ];

  # --- Nginx ---

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    serverTokens = false;

    virtualHosts."git.decio.us" = {
      listen = [
        {
          addr = "127.0.0.1";
          port = forgejoTunnelPort;
        }
      ];

      extraConfig = ''
        client_max_body_size 1G;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString forgejoPort}";
        proxyWebsockets = true;
        recommendedProxySettings = false;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Server $hostname;
        '';
      };
    };
  };
}

let
  conduitEdge = "conduit";

  minecraftA = name: {
    host = "${name}.adeci.net";
    type = "A";
    edge = conduitEdge;
    proxied = false;
  };

  minecraftSrv = name: stream: {
    host = "_minecraft._tcp.${name}.adeci.net";
    type = "SRV";
    ingressStream = {
      edge = conduitEdge;
      name = stream;
    };
    data = {
      priority = 0;
      weight = 0;
      target = "${name}.adeci.net";
    };
  };
in
{
  zones = [
    "decio.us"
    "adeci.dev"
    "adeci.net"
  ];

  # Keyed by machine, which gets its tunnel token as a clan var; healthPaths are probed.
  tunnels = {
    sequoia = {
      vault = {
        host = "vault.decio.us";
        port = 8222;
        healthPath = "/alive";
        firewall.customRules = [
          {
            # Admin: ssh -L 8222:localhost:8222 sequoia, then http://localhost:8222/admin
            description = "Vaultwarden: block the admin panel";
            action = "block";
            paths = [ "/admin" ];
          }
        ];
      };

      matrix = {
        host = "matrix.decio.us";
        port = 8448;
        healthPath = "/_matrix/client/versions";
      };

      # Matrix's server name, which only points at the homeserver.
      matrixWellKnown = {
        host = "decio.us";
        port = 8748;
        healthPath = "/.well-known/matrix/server";
      };

      ntfy = {
        host = "ntfy.decio.us";
        port = 2586;
        healthPath = "/v1/health";
      };
    };

    leviathan.nixbot = {
      host = "nixbot.decio.us";
      port = 80;
      healthPath = "/";
    };
  };

  # Clan var that terraform sets to each tunnel's token on the tunnel's machine.
  tunnelToken = {
    generator = "cloudflare-tunnel-token";
    file = "token";
  };

  # Shared clan var with the DNS API token for ACME challenges; prompted, not set by terraform.
  acmeTokenGenerator = "cloudflare-acme-decio-us";

  dns = {
    shares = {
      host = "share.decio.us";
      type = "A";
      edge = conduitEdge;
      proxied = false;
      healthPath = "/api/healthcheck";
    };

    ntfy_backup = {
      host = "ntfy-backup.decio.us";
      type = "A";
      edge = conduitEdge;
      proxied = false;
      healthPath = "/v1/health";
    };

    mc_dj2 = minecraftA "dj2";
    mc_gab = minecraftA "gab";

    srv_dj2 = minecraftSrv "dj2" "minecraft-dj2";
    srv_gab = minecraftSrv "gab" "minecraft-gab";
  };

  # Names Cloudflare answers with a redirect; nothing serves them.
  redirects = {
    macBootstrap = {
      host = "macbootstrap.decio.us";
      url = "https://raw.githubusercontent.com/adeci/root/main/packages/mac-install/bootstrap.sh";
      healthPath = "/";
    };

    raidho = {
      host = "raidho.decio.us";
      url = "https://sequoia.cymric-daggertooth.ts.net:8443";
    };
  };
}

# The Cloudflare zones, tunnels, DNS records, redirects and firewall rules, read as self.inventory.cloudflare.
let
  conduitEdge = "conduit";

  edgeA = name: {
    zone = "adeci.net";
    inherit name;
    type = "A";
    edge = conduitEdge;
    proxied = false;
  };

  minecraftA = edgeA;

  minecraftSrv = host: stream: {
    zone = "adeci.net";
    name = "_minecraft._tcp.${host}";
    type = "SRV";
    ingressStream = {
      edge = conduitEdge;
      name = stream;
    };
    data = {
      priority = 0;
      weight = 0;
      target = "${host}.adeci.net";
    };
  };
in
{
  zones = [
    "decio.us"
    "adeci.dev"
    "adeci.net"
  ];

  # Keys are clan machine names: each machine receives its tunnel's token as a clan var.
  tunnels = {
    sequoia = {
      "vault.decio.us".port = 8222;
      "matrix.decio.us".port = 8448;
      "decio.us".port = 8748;
      "ntfy.decio.us".port = 2586;
    };

    leviathan = {
      "nixbot.decio.us".port = 80;
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
      zone = "decio.us";
      name = "share";
      type = "A";
      edge = conduitEdge;
      proxied = false;
    };

    mc_dj2 = minecraftA "dj2";
    mc_gab = minecraftA "gab";

    srv_dj2 = minecraftSrv "dj2" "minecraft-dj2";
    srv_gab = minecraftSrv "gab" "minecraft-gab";
  };

  firewall = {
    hosts = {
      "vault.decio.us".customRules = [
        {
          # Admin: ssh -L 8222:localhost:8222 sequoia, then http://localhost:8222/admin
          description = "Vaultwarden: block the admin panel";
          action = "block";
          paths = [ "/admin" ];
        }
      ];
    };
  };

  # Hostnames Cloudflare answers with a redirect; nothing serves them.
  redirects = {
    "macbootstrap.decio.us" =
      "https://raw.githubusercontent.com/adeci/root/main/flake/mac-install/bootstrap.sh";
  };
}

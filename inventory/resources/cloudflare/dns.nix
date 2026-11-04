# DNS records managed via Terraform.
# Cloudflare owns DNS. Records may reference public edge/stream data, but the
# Cloudflare module decides how those references materialize.
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
  # Self-hosted Zipline endpoint; Cloudflare serves DNS only.
  shares = {
    zone = "decio.us";
    name = "share";
    type = "A";
    edge = conduitEdge;
    proxied = false;
  };

  # Minecraft A records point at the public edge.
  mc_dj2 = minecraftA "dj2";
  mc_gab = minecraftA "gab";

  # Minecraft SRV records derive ports from ingress streams.
  srv_dj2 = minecraftSrv "dj2" "minecraft-dj2";
  srv_gab = minecraftSrv "gab" "minecraft-gab";
}

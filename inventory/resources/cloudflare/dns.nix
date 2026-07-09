# DNS records managed via Terraform.
# Cloudflare owns DNS. Records may reference public edge/stream data, but the
# Cloudflare module decides how those references materialize.
let
  sequoiaTailnetIp = "100.116.83.84";

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
  # Private Paperless endpoint. Public DNS resolves to Sequoia's Tailnet IP;
  # Janus overrides this locally to Sequoia's LAN IP.
  paperless = {
    zone = "decio.us";
    name = "paperless";
    type = "A";
    content = sequoiaTailnetIp;
    proxied = false;
  };

  # Private LiteLLM admin endpoint. DNS points at Sequoia's Tailnet IP only.
  litellm = {
    zone = "decio.us";
    name = "litellm";
    type = "A";
    content = sequoiaTailnetIp;
    proxied = false;
  };

  # Private Atlas endpoint. DNS points at Sequoia's Tailnet IP only.
  atlas = {
    zone = "decio.us";
    name = "atlas";
    type = "A";
    content = sequoiaTailnetIp;
    proxied = false;
  };

  # Forgejo Git SSH on conduit (Hetzner).
  git_ssh = {
    zone = "decio.us";
    name = "git-ssh";
    type = "A";
    proxied = false;
    edge = conduitEdge;
  };

  # Minecraft A records point at the public edge.
  mc_rlc = minecraftA "rlc";
  mc_rats = minecraftA "rats";
  mc_dj2 = minecraftA "dj2";
  mc_bruh = minecraftA "bruh";
  mc_hunter = minecraftA "hunter";
  mc_jav = minecraftA "jav";
  mc_usf = minecraftA "usf";

  palworld = edgeA "palworld";

  # Minecraft SRV records derive ports from ingress streams.
  srv_rlc = minecraftSrv "rlc" "minecraft-rlc";
  srv_rats = minecraftSrv "rats" "minecraft-rats";
  srv_hunter = minecraftSrv "hunter" "minecraft-hunter";
  srv_jav = minecraftSrv "jav" "minecraft-jav";
  srv_dj2 = minecraftSrv "dj2" "minecraft-dj2";
  srv_usf = minecraftSrv "usf" "minecraft-usf";
}

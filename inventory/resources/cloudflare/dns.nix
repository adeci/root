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
}

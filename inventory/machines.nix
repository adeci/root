# One entry per clan machine, the source of the clan inventory, LAN reservations and tailnet addresses (Tailscale assigns those; a reinstall can change them).
{
  aegis = {
    tags = [
      "adeci-net"
      "wifi-preload"
    ];
    tailnet = "100.121.2.13";
  };

  atropos = {
    tags = [ "adeci-net" ];
    tailnet = "100.94.70.105";
    lan = {
      mac = "6c:4b:90:75:df:79";
      clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:c4:8c:38:f1:54:f6:d7:a4"; # systemd-networkd
      ip = "10.10.0.60";
      vlan = "trusted";
    };
  };

  bramble = {
    tags = [ "adeci-net" ];
    tailnet = "100.74.133.117";
  };

  chrysalis = {
    tags = [
      "adeci-net-ephemeral"
      "wifi-preload"
    ];
  };

  clotho = {
    tags = [ "adeci-net" ];
    tailnet = "100.87.22.3";
    lan = {
      mac = "6c:4b:90:1a:87:8f";
      clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:66:3c:b9:3c:ea:ef:3e:fa"; # systemd-networkd
      ip = "10.10.0.61";
      vlan = "trusted";
    };
  };

  conduit = {
    tags = [ "adeci-net" ];
    tailnet = "100.115.94.1";
  };

  icarus = {
    class = "darwin";
    tags = [ "adeci-net" ];
    tailnet = "100.86.7.91";
  };

  janus = {
    tags = [ "adeci-net" ];
    tailnet = "100.65.60.15";
  };

  kasha = {
    tags = [ "adeci-net" ];
    tailnet = "100.70.179.117";
  };

  lachesis = {
    tags = [ "adeci-net" ];
    tailnet = "100.65.112.40";
    lan = {
      mac = "6c:4b:90:18:da:ca";
      clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:73:db:fa:94:7e:19:65:ef"; # systemd-networkd
      ip = "10.40.0.62";
      vlan = "vault";
    };
  };

  leviathan = {
    tags = [ "adeci-net" ];
    tailnet = "100.90.108.13";
    lan = {
      mac = "e4:3d:1a:cd:96:60";
      ip = "10.10.0.20";
      vlan = "trusted";
    };
  };

  modus = {
    tags = [
      "adeci-net"
      "wifi-preload"
    ];
    tailnet = "100.104.206.85";
  };

  praxis = {
    tags = [
      "adeci-net"
      "wifi-preload"
    ];
    tailnet = "100.88.20.8";
  };

  proteus = {
    tags = [
      "adeci-net"
      "wifi-preload"
    ];
    tailnet = "100.78.27.92";
  };

  sequoia = {
    tags = [ "adeci-net" ];
    tailnet = "100.116.83.84";
    lan = {
      mac = "00:e0:4c:6d:c5:c9";
      ip = "10.10.0.10";
      vlan = "trusted";
    };
  };
}

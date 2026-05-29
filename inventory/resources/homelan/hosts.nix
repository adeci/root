{
  # Management network (VLAN 99)
  axon = {
    mac = "04:f4:1c:84:68:a6"; # sfp-sfpplus1 MAC (standalone management port)
    ip = "10.99.0.3";
    vlan = "mgmt";
  };

  nexus = {
    mac = "08:55:31:21:A7:0D";
    ip = "10.99.0.2";
    vlan = "mgmt";
  };

  nimbus = {
    mac = "04:F4:1C:EA:18:83";
    ip = "10.99.0.6";
    vlan = "mgmt";
  };

  zephyr = {
    mac = "04:F4:1C:E9:EF:E5";
    ip = "10.99.0.5";
    vlan = "mgmt";
  };

  # Trusted network (VLAN 10)
  aero = {
    mac = "d4:93:90:10:8c:d1";
    ip = "10.10.0.40";
    vlan = "trusted";
  };

  atropos = {
    mac = "6c:4b:90:75:df:79";
    clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:c4:8c:38:f1:54:f6:d7:a4"; # systemd-networkd
    ip = "10.10.0.60";
    vlan = "trusted";
  };

  clotho = {
    mac = "6c:4b:90:1a:87:8f";
    clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:1e:c6:9a:94:b1:70:1d:25"; # systemd-networkd
    ip = "10.10.0.61";
    vlan = "trusted";
  };

  lachesis = {
    mac = "6c:4b:90:18:da:ca";
    clientId = "ff:66:7b:93:2a:00:02:00:00:ab:11:bf:19:5c:d4:35:a7:60:ae"; # systemd-networkd
    ip = "10.10.0.62";
    vlan = "trusted";
  };

  leviathan = {
    mac = "e4:3d:1a:cd:96:60";
    ip = "10.10.0.20";
    vlan = "trusted";
  };

  leviathan-idrac = {
    mac = "b0:7b:25:f0:b0:c8";
    ip = "10.10.0.21";
    vlan = "trusted";
  };

  printer = {
    mac = "9c:93:4e:2e:6e:e1";
    ip = "10.10.0.50";
    vlan = "trusted";
    aliases = [ "xerox" ];
  };

  sequoia = {
    mac = "00:e0:4c:6d:c5:c9";
    ip = "10.10.0.10";
    vlan = "trusted";
    aliases = [ "scans" ];
  };
}

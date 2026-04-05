# MikroTik CRS310-8G+2S+IN — upstairs mini rack switch
{
  model = "CRS310-8G+2S+IN";
  host = "10.99.0.3"; # update after bootstrap + static lease
  port = 8728;

  identity = "axon";

  managementPort = "ether1"; # standalone, not in bridge, keeps DHCP client

  vlans = {
    trusted = 10;
    iot = 20;
    guest = 30;
    mgmt = 99;
  };

  defaultVlan = "trusted";

  ports = {
    "sfp-sfpplus1" = {
      trunk = true;
      comment = "Downlink — nexus";
    };
    # "ether5" = { vlan = "iot"; comment = "IoT device"; };
  };

  fallbackAddress = "172.16.0.3/24";
}

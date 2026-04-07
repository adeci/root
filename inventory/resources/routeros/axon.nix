# MikroTik CRS310-8G+2S+IN — upstairs mini rack switch
{
  model = "CRS310-8G+2S+IN";
  host = "10.99.0.210"; # TEMP — revert to 10.99.0.3 after janus static lease kicks in
  port = 8728;

  identity = "axon";

  managementPort = null; # all ether ports in bridge (single SFP+ uplink, no mgmt cable)
  fallbackPort = "ether1"; # fallback IP goes here for local laptop recovery

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
      comment = "Downlink — nexus (10G SFP+)";
    };
    # "ether5" = { vlan = "iot"; comment = "IoT device"; };
  };

  fallbackAddress = "172.16.0.3/24";
}

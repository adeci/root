# Upstairs mini rack
{
  model = "CRS310-8G+2S+IN";

  identity = "axon";

  managementPort = "sfp-sfpplus1";
  fallbackPort = "ether1"; # fallback IP goes here for local laptop recovery

  vlans = [
    "trusted"
    "iot"
    "guest"
    "vault"
    "mgmt"
  ];

  defaultVlan = "trusted";

  ports = {
    "sfp-sfpplus1" = {
      trunk = true;
      comment = "Downlink — nexus (10G SFP+)";
    };
    "ether1" = {
      vlan = "vault";
      comment = "Server — lachesis";
    };
    "ether4" = {
      vlan = "guest";
      comment = "Penumbra guest device";
    };
  };

  fallbackAddress = "172.16.0.3/24";
}

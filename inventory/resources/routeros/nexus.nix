# MikroTik CRS328-24P-4S+RM — main rack switch
{
  model = "CRS328-24P-4S+RM";
  host = "10.99.0.2";
  port = 8728;

  identity = "nexus";

  managementPort = "ether1"; # standalone, not in bridge, keeps DHCP client

  vlans = {
    trusted = 10;
    iot = 20;
    guest = 30;
    mgmt = 99;
  };

  # Ports not listed here default to access ports on this VLAN
  defaultVlan = "trusted";

  # Port overrides — only list what differs from the default
  ports = {
    "sfp-sfpplus1" = {
      trunk = true;
      comment = "Uplink — janus (10G SFP+)";
    };
    "sfp-sfpplus2" = {
      hybrid = true;
      vlan = "mgmt";
      tagged = [
        "trusted"
        "iot"
        "guest"
      ];
      comment = "Uplink — axon (10G SFP+)";
    };
    "ether2" = {
      hybrid = true;
      vlan = "mgmt";
      tagged = [
        "trusted"
        "iot"
        "guest"
      ];
      poe = "auto-on";
      comment = "WAP — zephyr (PoE+)";
    };
    "ether3" = {
      hybrid = true;
      vlan = "mgmt";
      tagged = [
        "trusted"
        "iot"
        "guest"
      ];
      poe = "auto-on";
      comment = "WAP — nimbus (PoE+)";
    };
    # "ether5" = { vlan = "iot"; comment = "Blink camera"; };
  };

  # Static fallback IP on management port (reachable if DHCP fails)
  fallbackAddress = "172.16.0.2/24";
}

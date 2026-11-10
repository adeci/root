# Main rack
{
  model = "CRS328-24P-4S+RM";
  host = "10.99.0.2";
  port = 8728;

  identity = "nexus";

  managementPort = "ether1"; # standalone, not in bridge, keeps DHCP client

  vlans = [
    "trusted"
    "iot"
    "guest"
    "vault"
    "tenant"
    "mgmt"
  ];

  defaultVlan = "trusted";

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
        "vault"
      ];
      comment = "Uplink — axon (10G SFP+)";
    };
    "sfp-sfpplus3" = {
      comment = "Server — leviathan trusted (10G SFP+)";
    };
    "sfp-sfpplus4" = {
      vlan = "tenant";
      comment = "Server — leviathan microVM tenants (10G SFP+)";
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
  };

  fallbackAddress = "172.16.0.2/24";
}

# Upstairs
{
  model = "cAP-ax";

  lan = {
    mac = "04:F4:1C:EA:18:83";
    ip = "10.99.0.6";
    vlan = "mgmt";
  };

  managementPort = "ether1";

  wifi = import ./wifi.nix;

  fallbackAddress = "172.16.0.6/24";
}

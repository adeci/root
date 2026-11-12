# Living room
{
  model = "cAP-ax";

  lan = {
    mac = "04:F4:1C:E9:EF:E5";
    ip = "10.99.0.5";
    vlan = "mgmt";
  };

  managementPort = "ether1";

  wifi = import ./wifi.nix;

  fallbackAddress = "172.16.0.5/24";
}

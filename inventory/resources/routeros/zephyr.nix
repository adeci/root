# Living room
{
  model = "cAP-ax";

  identity = "zephyr";

  managementPort = "ether1";

  wifi = import ./wifi.nix;

  fallbackAddress = "172.16.0.5/24";
}

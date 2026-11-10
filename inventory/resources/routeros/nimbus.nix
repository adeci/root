# Upstairs
{
  model = "cAP-ax";

  identity = "nimbus";

  managementPort = "ether1";

  wifi = import ./wifi.nix;

  fallbackAddress = "172.16.0.6/24";
}

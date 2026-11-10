# SSIDs every access point broadcasts.
{
  main = {
    ssid = "Aether";
    vlan = "trusted";
    security = "wpa2-wpa3";
    secret = "wifi-aether";
    primary = true;
  };
  guest = {
    ssid = "Penumbra";
    vlan = "guest";
    security = "wpa2-wpa3";
    secret = "wifi-penumbra";
  };
  iot = {
    ssid = "Mycelium";
    vlan = "iot";
    security = "wpa2-wpa3";
    hidden = true;
    secret = "wifi-mycelium";
  };
}

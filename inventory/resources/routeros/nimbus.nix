# MikroTik cAP ax (Gen 6) — upstairs WAP
{
  model = "cAP-ax";
  host = "10.99.0.6";
  port = 8728;

  identity = "nimbus";

  managementPort = "ether1";

  wifi = {
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
  };

  fallbackAddress = "172.16.0.6/24";
}

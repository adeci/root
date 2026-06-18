# MikroTik cAP ax (Gen 6) — living room WAP
{
  model = "cAP-ax";
  host = "10.99.0.5";
  port = 8728;

  identity = "zephyr";

  managementPort = "ether1";

  wifi = {
    main = {
      ssid = "Aether";
      vlan = "trusted";
      security = "wpa2-wpa3";
      secret = "wifi-aether";
      primary = true; # bound to physical radios, others get virtual interfaces
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

  fallbackAddress = "172.16.0.5/24";
}

# Per MikroTik model: its RouterOS architecture, extra packages, port counts and radios.
{
  "CRS328-24P-4S+RM" = {
    arch = "arm";
    etherPorts = 24;
    sfpPorts = 4;
  };
  "CRS310-8G+2S+IN" = {
    arch = "arm";
    etherPorts = 8;
    sfpPorts = 2;
  };
  "cAP-ax" = {
    arch = "arm64";
    extraPackages = [ "wifi-qcom" ];
    etherPorts = 2;
    sfpPorts = 0;
    # wifi1 is 5GHz and wifi2 2.4GHz; these ids are stable after netinstall.
    radios = [
      {
        name = "wifi1";
        id = "*2";
      }
      {
        name = "wifi2";
        id = "*3";
      }
    ];
  };
}

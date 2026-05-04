{
  wifi = {
    module = {
      name = "wifi";
      input = "clan-core";
    };
    roles.default = {
      tags = [ "wifi-preload" ];
      settings.networks = {
        home = { };
        hotspot = { };
      };
    };
  };
}

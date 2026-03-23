{
  wifi = {
    module = {
      name = "wifi";
      input = "clan-core";
    };
    roles.default = {
      tags = [ "wayfinders" ];
      settings.networks = {
        home = { };
        hotspot = { };
      };
    };
  };
}

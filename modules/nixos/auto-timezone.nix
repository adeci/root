{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.auto-timezone;
in
{
  options.adeci.auto-timezone.enable = lib.mkEnableOption "automatic timezone detection via geolocation";
  config = lib.mkIf cfg.enable {
    services.automatic-timezoned.enable = true;
    services.geoclue2.geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
    time.timeZone = null;
  };
}

{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (import ../lib.nix { inherit config lib self'; }) safeName;
  inherit (self.inventory.cloudflare) zones;

  zoneId = zone: config.data.cloudflare_zone.${safeName zone} "id";
in
{
  data.cloudflare_zone = lib.listToAttrs (
    map (zone: lib.nameValuePair (safeName zone) { filter.name = zone; }) zones
  );

  # HSTS reaches proxied hostnames only; DNS-only ones need their origin to send it.
  resource.cloudflare_zone_setting = lib.listToAttrs (
    map (
      zone:
      lib.nameValuePair "${safeName zone}_security_header" {
        zone_id = zoneId zone;
        setting_id = "security_header";
        value.strict_transport_security = {
          enabled = true;
          max_age = 31536000;
          include_subdomains = true;
          preload = true;
          nosniff = true;
        };
      }
    ) zones
  );

  # Provider v5 cannot take over v4's cloudflare_zone_settings_override, so it adopts the setting each zone already has.
  import = map (zone: {
    to = "cloudflare_zone_setting.${safeName zone}_security_header";
    id = "${zoneId zone}/security_header";
  }) zones;
}

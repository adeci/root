{
  clan-cli,
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../lib.nix { inherit clan-cli lib; }) safeName;
  inherit (self.inventory.cloudflare) zones;
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
        zone_id = config.data.cloudflare_zone.${safeName zone} "id";
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
}

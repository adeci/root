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
in
{
  data.cloudflare_zone = lib.listToAttrs (
    map (zone: lib.nameValuePair (safeName zone) { name = zone; }) zones
  );

  # HSTS reaches proxied hostnames only; DNS-only ones need their origin to send it.
  resource.cloudflare_zone_settings_override = lib.listToAttrs (
    map (
      zone:
      lib.nameValuePair (safeName zone) {
        zone_id = config.data.cloudflare_zone.${safeName zone} "id";
        settings.security_header = {
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

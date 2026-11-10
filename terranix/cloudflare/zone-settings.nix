# HSTS here covers proxied hostnames only; DNS-only records bypass Cloudflare,
# so their origin must send the header itself.
{
  config,
  self,
  lib,
  ...
}:
let
  inherit (self.resources.cloudflare) zones;
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
in
{
  resource.cloudflare_zone_settings_override = lib.listToAttrs (
    map (zone: {
      name = safeName zone;
      value = {
        zone_id = config.data.cloudflare_zone.${safeName zone} "id";
        settings.security_header = {
          enabled = true;
          max_age = 31536000;
          include_subdomains = true;
          preload = true;
          nosniff = true;
        };
      };
    }) zones
  );
}

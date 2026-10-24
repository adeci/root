# Per-zone settings. HSTS covers every proxied hostname (tunnels); DNS-only
# records such as share.decio.us bypass Cloudflare and set it in nginx.
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
          # Starts at one day; raise to a year once it's proven.
          max_age = 86400;
          include_subdomains = false;
          nosniff = true;
        };
      };
    }) zones
  );
}

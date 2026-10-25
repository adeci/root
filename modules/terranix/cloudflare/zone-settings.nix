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
          max_age = 31536000;
          include_subdomains = true;
          preload = true;
          nosniff = true;
        };
      };
    }) zones
  );
}

# Each redirect gets a proxied placeholder record (100:: is Cloudflare's address for hostnames without an origin) and a rule in its zone's dynamic redirect ruleset.
{
  config,
  self,
  lib,
  ...
}:
let
  inherit (self.resources.cloudflare) zones redirects;
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
  zoneId = zone: config.data.cloudflare_zone.${safeName zone} "id";

  zoneOf =
    hostname:
    lib.findFirst (
      zone: hostname == zone || lib.hasSuffix ".${zone}" hostname
    ) (throw "Cloudflare redirect ${hostname} does not match any configured zone") zones;

  recordName =
    hostname:
    let
      zone = zoneOf hostname;
    in
    if hostname == zone then "@" else lib.removeSuffix ".${zone}" hostname;
in
{
  resource.cloudflare_record = lib.mapAttrs' (
    hostname: _:
    lib.nameValuePair "redirect_${safeName hostname}" {
      zone_id = zoneId (zoneOf hostname);
      name = recordName hostname;
      type = "AAAA";
      content = "100::";
      proxied = true;
    }
  ) redirects;

  resource.cloudflare_ruleset = lib.mapAttrs' (
    zone: hostnames:
    lib.nameValuePair "http_request_dynamic_redirect_${safeName zone}" {
      zone_id = zoneId zone;
      name = "Redirects (${zone})";
      description = "Redirect-only hostnames managed by Terranix.";
      kind = "zone";
      phase = "http_request_dynamic_redirect";
      rules = map (hostname: {
        ref = "redirect_${safeName hostname}";
        action = "redirect";
        description = "${hostname} to ${redirects.${hostname}}";
        enabled = true;
        expression = "(http.host eq ${builtins.toJSON hostname})";
        action_parameters.from_value = {
          status_code = 302;
          target_url.value = redirects.${hostname};
          preserve_query_string = false;
        };
      }) hostnames;
    }
  ) (lib.groupBy zoneOf (builtins.attrNames redirects));
}

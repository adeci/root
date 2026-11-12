# Each redirect gets a proxied placeholder record (100:: is Cloudflare's address for hostnames without an origin) and a rule in its zone's dynamic redirect ruleset.
{
  self,
  lib,
  safeName,
  zoneId,
  hostnameParts,
  ...
}:
let
  inherit (self.resources.cloudflare) redirects;
  zoneOf = hostname: (hostnameParts hostname).zone;
in
{
  resource.cloudflare_record = lib.mapAttrs' (
    hostname: _:
    let
      parts = hostnameParts hostname;
    in
    lib.nameValuePair "redirect_${safeName hostname}" {
      zone_id = zoneId parts.zone;
      inherit (parts) name;
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

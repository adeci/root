# Cloudflare Rulesets API resources.
# API tokens need Zone WAF/Rulesets edit.
{
  config,
  self,
  lib,
  ...
}:
let
  inherit (self.resources.cloudflare) firewall zones;
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
  cfString = builtins.toJSON;

  zoneForHost =
    hostname:
    let
      matches = builtins.filter (zone: hostname == zone || lib.hasSuffix ".${zone}" hostname) zones;
      sortedMatches = lib.sort (a: b: builtins.stringLength a > builtins.stringLength b) matches;
    in
    if sortedMatches == [ ] then
      throw "Cloudflare firewall hostname ${hostname} does not match any configured zone"
    else
      builtins.head sortedMatches;

  mkSkipRule =
    hostname: hostRule: path:
    let
      checkedPath =
        if lib.hasPrefix "/" path then
          path
        else
          throw "Cloudflare firewall path for ${hostname} must start with /: ${path}";
      skipProducts = hostRule.skipProducts or [ ];
      userAgentPrefixes = hostRule.userAgentPrefixes or [ ];
      userAgentExpression =
        lib.optionalString (userAgentPrefixes != [ ])
          " and (${
             lib.concatMapStringsSep " or " (
               prefix: "starts_with(http.user_agent, ${cfString prefix})"
             ) userAgentPrefixes
           })";
    in
    if skipProducts == [ ] then
      throw "Cloudflare firewall rule for ${hostname}${checkedPath} must define skipProducts"
    else
      {
        zone = zoneForHost hostname;
        rule = {
          action = "skip";
          action_parameters.products = skipProducts;
          description = hostRule.description or "Skip Cloudflare products for ${hostname}${checkedPath}*";
          enabled = hostRule.enabled or true;
          expression = "(http.host eq ${cfString hostname} and starts_with(http.request.uri.path, ${cfString checkedPath})${userAgentExpression})";
          logging.enabled = true;
        };
      };

  skipRules = lib.flatten (
    lib.mapAttrsToList (
      hostname: hostConfig:
      lib.flatten (
        map (hostRule: map (mkSkipRule hostname hostRule) hostRule.paths) (hostConfig.rules or [ ])
      )
    ) (firewall.hosts or { })
  );

  rulesByZone = builtins.groupBy (entry: entry.zone) skipRules;

  mkRuleset = zone: entries: {
    zone_id = config.data.cloudflare_zone.${safeName zone} "id";
    name = "Custom HTTP request firewall rules (${zone})";
    description = "Zone-level custom firewall rules managed by Terranix.";
    kind = "zone";
    phase = "http_request_firewall_custom";
    rules = map (entry: entry.rule) entries;
  };
in
{
  resource.cloudflare_ruleset = lib.mapAttrs' (
    zone: entries:
    lib.nameValuePair "http_request_firewall_custom_${safeName zone}" (mkRuleset zone entries)
  ) rulesByZone;
}

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

  checkedPath =
    hostname: path:
    if lib.hasPrefix "/" path then
      path
    else
      throw "Cloudflare firewall path for ${hostname} must start with /: ${path}";

  hostExpression = hostname: expression: "(http.host eq ${cfString hostname} and (${expression}))";

  pathsExpression =
    hostname: paths:
    if paths == [ ] then
      null
    else
      "(${
        lib.concatMapStringsSep " or " (
          path: "starts_with(http.request.uri.path, ${cfString (checkedPath hostname path)})"
        ) paths
      })";

  methodsExpression =
    methods:
    if methods == [ ] then
      null
    else
      "http.request.method in {${lib.concatMapStringsSep " " cfString methods}}";

  compact = builtins.filter (value: value != null && value != "");

  mkRuleExpression =
    hostname: rule:
    let
      paths = rule.paths or [ ];
      methods = rule.methods or [ ];
      parts = compact [
        (pathsExpression hostname paths)
        (methodsExpression methods)
        (rule.expression or null)
      ];
    in
    if parts == [ ] then
      throw "Cloudflare firewall rule for ${hostname} must define paths, methods, or expression"
    else
      hostExpression hostname (lib.concatStringsSep " and " parts);

  mkSkipRule =
    hostname: hostRule: path:
    let
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
      throw "Cloudflare firewall rule for ${hostname}${checkedPath hostname path} must define skipProducts"
    else
      {
        zone = zoneForHost hostname;
        rule = {
          action = "skip";
          action_parameters.products = skipProducts;
          description =
            hostRule.description or "Skip Cloudflare products for ${hostname}${checkedPath hostname path}*";
          enabled = hostRule.enabled or true;
          expression = "(http.host eq ${cfString hostname} and starts_with(http.request.uri.path, ${cfString (checkedPath hostname path)})${userAgentExpression})";
          logging.enabled = hostRule.loggingEnabled or true;
        };
      };

  mkCustomRule =
    hostname: rule:
    let
      action = rule.action or "block";
    in
    {
      zone = zoneForHost hostname;
      rule = {
        inherit action;
        description = rule.description or "Custom firewall rule for ${hostname}";
        enabled = rule.enabled or true;
        expression = mkRuleExpression hostname rule;
      }
      // lib.optionalAttrs (rule ? action_parameters) {
        inherit (rule) action_parameters;
      }
      // lib.optionalAttrs (rule ? loggingEnabled && action == "skip") {
        logging.enabled = rule.loggingEnabled;
      };
    };

  mkRateLimitRule = hostname: rule: {
    zone = zoneForHost hostname;
    rule = {
      action = rule.action or "block";
      description = rule.description or "Rate limit ${hostname}";
      enabled = rule.enabled or true;
      expression = mkRuleExpression hostname rule;
      ratelimit = {
        characteristics =
          rule.characteristics or [
            "cf.colo.id"
            "ip.src"
          ];
        period = rule.period or 60;
        requests_per_period = rule.requestsPerPeriod;
        mitigation_timeout = rule.mitigationTimeout or 60;
      }
      // lib.optionalAttrs (rule ? countingExpression) {
        counting_expression = rule.countingExpression;
      }
      // lib.optionalAttrs (rule ? requestsToOrigin) {
        requests_to_origin = rule.requestsToOrigin;
      };
    }
    // lib.optionalAttrs (rule ? action_parameters) {
      inherit (rule) action_parameters;
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

  customRules = lib.flatten (
    lib.mapAttrsToList (
      hostname: hostConfig: map (mkCustomRule hostname) (hostConfig.customRules or [ ])
    ) (firewall.hosts or { })
  );

  rateLimitRules = lib.flatten (
    lib.mapAttrsToList (
      hostname: hostConfig: map (mkRateLimitRule hostname) (hostConfig.rateLimits or [ ])
    ) (firewall.hosts or { })
  );

  firewallRulesByZone = builtins.groupBy (entry: entry.zone) (skipRules ++ customRules);
  rateLimitRulesByZone = builtins.groupBy (entry: entry.zone) rateLimitRules;

  mkRuleset = phase: name: description: zone: entries: {
    zone_id = config.data.cloudflare_zone.${safeName zone} "id";
    inherit phase name description;
    kind = "zone";
    rules = map (entry: entry.rule) entries;
  };

  mkFirewallRuleset =
    zone: entries:
    mkRuleset "http_request_firewall_custom" "Custom HTTP request firewall rules (${zone})"
      "Zone-level custom firewall rules managed by Terranix."
      zone
      entries;

  mkRateLimitRuleset =
    zone: entries:
    mkRuleset "http_ratelimit" "HTTP rate limiting rules (${zone})"
      "Zone-level rate limiting rules managed by Terranix."
      zone
      entries;
in
{
  resource.cloudflare_ruleset =
    (lib.mapAttrs' (
      zone: entries:
      lib.nameValuePair "http_request_firewall_custom_${safeName zone}" (mkFirewallRuleset zone entries)
    ) firewallRulesByZone)
    // (lib.mapAttrs' (
      zone: entries: lib.nameValuePair "http_ratelimit_${safeName zone}" (mkRateLimitRuleset zone entries)
    ) rateLimitRulesByZone);
}

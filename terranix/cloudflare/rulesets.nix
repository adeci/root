{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (import ../lib.nix { inherit config lib self'; }) safeName;
  inherit (self.inventory.cloudflare) firewall redirects zones;
  inherit (import ./lib.nix { inherit lib zones; })
    hostExpression
    ruleExpression
    skipExpression
    zoneOf
    ;

  hosts = firewall.hosts or { };

  skipRule =
    hostname: skip: path:
    let
      skipProducts = skip.skipProducts or [ ];
    in
    if skipProducts == [ ] then
      throw "Cloudflare firewall rule for ${hostname}${path} must define skipProducts"
    else
      {
        zone = zoneOf hostname;
        rule = {
          action = "skip";
          action_parameters.products = skipProducts;
          description = skip.description or "Skip Cloudflare products for ${hostname}${path}*";
          enabled = skip.enabled or true;
          expression = skipExpression hostname path (skip.userAgentPrefixes or [ ]);
          logging.enabled = skip.loggingEnabled or true;
        };
      };

  customRule =
    hostname: custom:
    let
      action = custom.action or "block";
    in
    {
      zone = zoneOf hostname;
      rule = {
        inherit action;
        description = custom.description or "Custom firewall rule for ${hostname}";
        enabled = custom.enabled or true;
        expression = ruleExpression hostname custom;
      }
      // lib.optionalAttrs (custom ? action_parameters) {
        inherit (custom) action_parameters;
      }
      # Cloudflare rejects logging settings on rules other than skip.
      // lib.optionalAttrs (custom ? loggingEnabled && action == "skip") {
        logging.enabled = custom.loggingEnabled;
      };
    };

  rateLimitRule = hostname: rateLimit: {
    zone = zoneOf hostname;
    rule = {
      action = rateLimit.action or "block";
      description = rateLimit.description or "Rate limit ${hostname}";
      enabled = rateLimit.enabled or true;
      expression = ruleExpression hostname rateLimit;
      ratelimit = {
        characteristics =
          rateLimit.characteristics or [
            "cf.colo.id"
            "ip.src"
          ];
        period = rateLimit.period or 60;
        requests_per_period = rateLimit.requestsPerPeriod;
        mitigation_timeout = rateLimit.mitigationTimeout or 60;
      }
      // lib.optionalAttrs (rateLimit ? countingExpression) {
        counting_expression = rateLimit.countingExpression;
      }
      // lib.optionalAttrs (rateLimit ? requestsToOrigin) {
        requests_to_origin = rateLimit.requestsToOrigin;
      };
    }
    // lib.optionalAttrs (rateLimit ? action_parameters) {
      inherit (rateLimit) action_parameters;
    };
  };

  redirectRule = hostname: url: {
    zone = zoneOf hostname;
    rule = {
      ref = "redirect_${safeName hostname}";
      action = "redirect";
      description = "${hostname} to ${url}";
      enabled = true;
      expression = hostExpression hostname [ ];
      action_parameters.from_value = {
        status_code = 302;
        target_url.value = url;
        preserve_query_string = false;
      };
    };
  };

  skipRules = lib.concatLists (
    lib.mapAttrsToList (
      hostname: host: lib.concatMap (skip: map (skipRule hostname skip) skip.paths) (host.rules or [ ])
    ) hosts
  );

  customRules = lib.concatLists (
    lib.mapAttrsToList (hostname: host: map (customRule hostname) (host.customRules or [ ])) hosts
  );

  rateLimitRules = lib.concatLists (
    lib.mapAttrsToList (hostname: host: map (rateLimitRule hostname) (host.rateLimits or [ ])) hosts
  );

  redirectRules = lib.mapAttrsToList redirectRule redirects;

  # Rules come as { zone, rule }; each zone with rules gets one ruleset for the phase.
  rulesets =
    {
      phase,
      title,
      description,
      rules,
    }:
    lib.mapAttrs' (
      zone: zoneRules:
      lib.nameValuePair "${phase}_${safeName zone}" {
        zone_id = config.data.cloudflare_zone.${safeName zone} "id";
        inherit phase description;
        name = "${title} (${zone})";
        kind = "zone";
        rules = map (entry: entry.rule) zoneRules;
      }
    ) (lib.groupBy (entry: entry.zone) rules);
in
{
  # API tokens need Zone WAF/Rulesets edit.
  resource.cloudflare_ruleset = lib.mkMerge (
    map rulesets [
      {
        phase = "http_request_firewall_custom";
        title = "Custom HTTP request firewall rules";
        description = "Zone-level custom firewall rules managed by Terranix.";
        rules = skipRules ++ customRules;
      }
      {
        phase = "http_ratelimit";
        title = "HTTP rate limiting rules";
        description = "Zone-level rate limiting rules managed by Terranix.";
        rules = rateLimitRules;
      }
      {
        phase = "http_request_dynamic_redirect";
        title = "Redirects";
        description = "Redirect-only hostnames managed by Terranix.";
        rules = redirectRules;
      }
    ]
  );
}

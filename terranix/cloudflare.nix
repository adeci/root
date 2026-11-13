{
  config,
  lib,
  self,
  clanSecret,
  safeName,
  setClanVar,
  ...
}:
let
  inherit (self.inventory.cloudflare)
    zones
    tunnels
    tunnelToken
    dns
    redirects
    firewall
    ;

  zoneId = zone: config.data.cloudflare_zone.${safeName zone} "id";

  # The zone a hostname is in (the longest that matches), and its record name there: "@" at the apex.
  hostnameParts =
    hostname:
    let
      matches = lib.filter (zone: hostname == zone || lib.hasSuffix ".${zone}" hostname) zones;
      longestFirst = lib.sort (a: b: lib.stringLength a > lib.stringLength b) matches;
      zone = lib.head longestFirst;
    in
    if matches == [ ] then
      throw "Cloudflare hostname ${hostname} is in none of the configured zones"
    else
      {
        inherit zone;
        name = if hostname == zone then "@" else lib.removeSuffix ".${zone}" hostname;
      };

  zoneOf = hostname: (hostnameParts hostname).zone;

  resolveTarget = target: config.resource.${target.resource}.${target.name} target.field;

  edgeAddress =
    edgeName:
    let
      edge = self.inventory.ingress.edges.${edgeName};
    in
    if edge.provider == "hcloud" then
      config.resource.hcloud_server.${edgeName} "ipv4_address"
    else
      throw "Cloudflare DNS edge target ${edgeName}: unsupported provider ${edge.provider}";

  ingressStream =
    ref:
    let
      matches = lib.filter (stream: stream.name == ref.name) (
        self.inventory.ingress.streams.${ref.edge} or [ ]
      );
    in
    if lib.length matches == 1 then
      builtins.head matches
    else if matches == [ ] then
      throw "Cloudflare DNS ingress stream ${ref.edge}/${ref.name}: no matching stream"
    else
      throw "Cloudflare DNS ingress stream ${ref.edge}/${ref.name}: duplicate stream name";

  cfString = builtins.toJSON;

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
        zone = zoneOf hostname;
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
      zone = zoneOf hostname;
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
    zone = zoneOf hostname;
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

  firewallRulesByZone = lib.groupBy (entry: entry.zone) (skipRules ++ customRules);
  rateLimitRulesByZone = lib.groupBy (entry: entry.zone) rateLimitRules;

  mkRuleset = phase: name: description: zone: entries: {
    zone_id = zoneId zone;
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
  terraform.required_providers.cloudflare = {
    source = "cloudflare/cloudflare";
    version = "~> 4.0";
  };

  terraform.required_providers.random = {
    source = "hashicorp/random";
    version = "~> 3.9";
  };

  clanSecrets = [
    "cloudflare-api-token"
    "cloudflare-account-id"
  ];

  provider.cloudflare = {
    api_token = clanSecret "cloudflare-api-token";
  };

  data.cloudflare_zone = lib.listToAttrs (
    map (zone: {
      name = safeName zone;
      value.name = zone;
    }) zones
  );

  # HSTS here covers proxied hostnames only; DNS-only records bypass Cloudflare, so their origin must send the header itself.
  resource.cloudflare_zone_settings_override = lib.listToAttrs (
    map (zone: {
      name = safeName zone;
      value = {
        zone_id = zoneId zone;
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

  # random_bytes, not random_id: random_id exposes the secret as its id.
  resource.random_bytes = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_secret_${machine}" {
      length = 32;
    }
  ) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair machine {
      account_id = clanSecret "cloudflare-account-id";
      name = machine;
      secret = config.resource.random_bytes."tunnel_secret_${machine}" "base64";
      config_src = "cloudflare";
    }
  ) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared_config = lib.mapAttrs' (
    machine: ingress:
    lib.nameValuePair machine {
      account_id = clanSecret "cloudflare-account-id";
      tunnel_id = config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id";

      config.ingress_rule =
        (lib.mapAttrsToList (hostname: route: {
          inherit hostname;
          service = "http://localhost:${toString route.port}";
        }) ingress)
        ++ [
          { service = "http_status:404"; }
        ];
    }
  ) tunnels;

  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    let
      tunnelId = config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id";
    in
    lib.nameValuePair "tunnel_token_${machine}" {
      input = tunnelId;
      triggers_replace = [ tunnelId ];

      provisioner.local-exec = {
        # terraform_data echoes its input unredacted, so only the tunnel ID goes there; the token goes straight to the provisioner.
        environment.TUNNEL_TOKEN = "\${sensitive(cloudflare_zero_trust_tunnel_cloudflared.${machine}.tunnel_token)}";
        command = ''
          printf '%s\n' "$TUNNEL_TOKEN" | ${setClanVar machine tunnelToken}
        '';
      };
    }
  ) tunnels;

  resource.cloudflare_record =
    let
      tunnelRecords = lib.concatMapAttrs (
        machine: ingress:
        lib.mapAttrs' (
          hostname: _:
          let
            parts = hostnameParts hostname;
          in
          lib.nameValuePair "tunnel_${safeName hostname}" {
            zone_id = zoneId parts.zone;
            inherit (parts) name;
            type = "CNAME";
            content = "${
              config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id"
            }.cfargotunnel.com";
            proxied = true;
          }
        ) ingress
      ) tunnels;

      dnsRecords = lib.mapAttrs (
        _: record:
        let
          stream = if record ? ingressStream then ingressStream record.ingressStream else null;
          passthrough = removeAttrs record [
            "zone"
            "target"
            "edge"
            "ingressStream"
          ];
        in
        passthrough
        // {
          zone_id = zoneId record.zone;
        }
        // lib.optionalAttrs (record ? target) {
          content = resolveTarget record.target;
        }
        // lib.optionalAttrs (record ? edge) {
          content = edgeAddress record.edge;
        }
        // lib.optionalAttrs (stream != null) {
          data = (record.data or { }) // {
            port = stream.listen;
          };
        }
      ) dns;

      # Each redirect gets a proxied placeholder record (100:: is Cloudflare's address for hostnames without an origin) and a rule in its zone's dynamic redirect ruleset.
      redirectRecords = lib.mapAttrs' (
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
    in
    tunnelRecords // dnsRecords // redirectRecords;

  # API tokens need Zone WAF/Rulesets edit.
  resource.cloudflare_ruleset =
    let
      firewallRulesets = lib.mapAttrs' (
        zone: entries:
        lib.nameValuePair "http_request_firewall_custom_${safeName zone}" (mkFirewallRuleset zone entries)
      ) firewallRulesByZone;

      rateLimitRulesets = lib.mapAttrs' (
        zone: entries: lib.nameValuePair "http_ratelimit_${safeName zone}" (mkRateLimitRuleset zone entries)
      ) rateLimitRulesByZone;

      redirectRulesets = lib.mapAttrs' (
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
            expression = "(http.host eq ${cfString hostname})";
            action_parameters.from_value = {
              status_code = 302;
              target_url.value = redirects.${hostname};
              preserve_query_string = false;
            };
          }) hostnames;
        }
      ) (lib.groupBy zoneOf (builtins.attrNames redirects));
    in
    firewallRulesets // rateLimitRulesets // redirectRulesets;
}

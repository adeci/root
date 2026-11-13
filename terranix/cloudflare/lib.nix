{ lib, zones }:
let
  quote = builtins.toJSON;

  allOf = expressions: "(${lib.concatStringsSep " and " expressions})";
  anyOf = expressions: "(${lib.concatStringsSep " or " expressions})";

  pathExpression =
    hostname: path:
    if lib.hasPrefix "/" path then
      "starts_with(http.request.uri.path, ${quote path})"
    else
      throw "Cloudflare firewall path for ${hostname} must start with /: ${path}";

  methodsExpression =
    methods: "http.request.method in {${lib.concatMapStringsSep " " quote methods}}";

  userAgentExpression = prefix: "starts_with(http.user_agent, ${quote prefix})";

  # Requests to the hostname that meet every condition.
  hostExpression = hostname: conditions: allOf ([ "http.host eq ${quote hostname}" ] ++ conditions);

  # The longest configured zone the hostname is in.
  zoneOf =
    hostname:
    let
      matches = lib.filter (zone: hostname == zone || lib.hasSuffix ".${zone}" hostname) zones;
    in
    if matches == [ ] then
      throw "Cloudflare hostname ${hostname} is in none of the configured zones"
    else
      lib.last (lib.sortOn lib.stringLength matches);
in
{
  inherit hostExpression zoneOf;

  # The hostname's record name in its zone: "@" at the apex.
  recordName =
    hostname:
    let
      zone = zoneOf hostname;
    in
    if hostname == zone then "@" else lib.removeSuffix ".${zone}" hostname;

  # Requests to the hostname matching the rule's paths, methods and expression, whichever it gives.
  ruleExpression =
    hostname: rule:
    let
      paths = rule.paths or [ ];
      methods = rule.methods or [ ];
      expression = rule.expression or null;
      conditions =
        lib.optional (paths != [ ]) (anyOf (map (pathExpression hostname) paths))
        ++ lib.optional (methods != [ ]) (methodsExpression methods)
        ++ lib.optional (expression != null && expression != "") expression;
    in
    if conditions == [ ] then
      throw "Cloudflare firewall rule for ${hostname} must define paths, methods, or expression"
    else
      hostExpression hostname [ (allOf conditions) ];

  # Requests to the hostname under the path, from any of the user-agent prefixes if there are some.
  skipExpression =
    hostname: path: userAgentPrefixes:
    hostExpression hostname (
      [ (pathExpression hostname path) ]
      ++ lib.optional (userAgentPrefixes != [ ]) (anyOf (map userAgentExpression userAgentPrefixes))
    );
}

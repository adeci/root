{
  config,
  self,
  self',
  lib,
  ...
}:
let
  inherit (self.resources) ingress;

  hcloudEdges = lib.filterAttrs (_: edge: edge.provider == "hcloud") ingress.edges;
  validProtocols = [
    "tcp"
    "udp"
  ];
  isPort = port: builtins.isInt port && port > 0 && port <= 65535;

  mkRule = rule: {
    direction = "in";
    inherit (rule) protocol;
    port = toString rule.port;
    source_ips = [
      "0.0.0.0/0"
      "::/0"
    ];
  };

  streamToRule = stream: {
    inherit (stream) protocol;
    port = stream.listen;
  };

  ruleKey = rule: "${rule.protocol}:${toString rule.port}";
  checkedRulesFor =
    edgeName: edge:
    let
      staticRules = edge.firewall.staticRules or [ ];
      streamRules = map streamToRule (ingress.streams.${edgeName} or [ ]);
      rules = staticRules ++ streamRules;
      keys = map ruleKey rules;
      invalidProtocols = lib.filter (rule: !(lib.elem rule.protocol validProtocols)) rules;
      invalidPorts = lib.filter (rule: !(isPort rule.port)) rules;
    in
    if invalidProtocols != [ ] then
      throw "hcloud edge ${edgeName}: firewall protocols must be tcp or udp."
    else if invalidPorts != [ ] then
      throw "hcloud edge ${edgeName}: firewall ports must be integers from 1 to 65535."
    else if keys != lib.unique keys then
      throw "hcloud edge ${edgeName}: duplicate protocol/port firewall rules are not allowed."
    else
      rules;
in
{
  terraform.required_providers = {
    hcloud = {
      source = "hetznercloud/hcloud";
    };
    external = {
      source = "registry.opentofu.org/hashicorp/external";
      version = "~> 2.0";
    };
  };

  data.external.hcloud-api-token = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "hcloud-api-token"
    ];
  };

  provider.hcloud = {
    token = config.data.external.hcloud-api-token "result.secret";
  };

  resource.hcloud_firewall = lib.mapAttrs (edgeName: edge: {
    name = edge.firewall.name or edgeName;
    rule = map mkRule (checkedRulesFor edgeName edge);
  }) hcloudEdges;
}

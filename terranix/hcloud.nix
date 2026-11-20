{
  clan-cli,
  lib,
  self,
  ...
}:
let
  inherit (self.inventory) ingress;
  inherit (import ./lib.nix { inherit clan-cli lib; }) clanSecret;

  hcloudEdges = lib.filterAttrs (_: edge: edge.provider == "hcloud") ingress.edges;

  # What an edge opens to the world: its static rules and each stream's listen port.
  openPorts =
    edgeName: edge:
    edge.firewall.staticRules or [ ]
    ++ map (stream: {
      inherit (stream) protocol;
      port = stream.listen;
    }) (ingress.streams.${edgeName} or [ ]);
in
{
  clanSecrets = [ "hcloud-api-token" ];

  provider.hcloud = {
    token = clanSecret "hcloud-api-token";
  };

  resource.hcloud_firewall = lib.mapAttrs (edgeName: edge: {
    name = edge.firewall.name or edgeName;
    rule = map (open: {
      direction = "in";
      inherit (open) protocol;
      port = toString open.port;
      source_ips = [
        "0.0.0.0/0"
        "::/0"
      ];
    }) (openPorts edgeName edge);
  }) hcloudEdges;
}

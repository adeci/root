# Monitoring agent settings for the router.
inventory:
let
  network = import ./network.nix inventory;
in
{
  extraCollectors = [ "conntrack" ];
  extraLabels.role = "router";
  rules = import ./rules.nix network;
  dashboards.network = import ./dashboard network;
}

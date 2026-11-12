# Monitoring agent settings for the router: its alert rules and dashboard, derived from the homelan inventory.
{ homelan, routeros }:
let
  network = import ./network.nix { inherit homelan routeros; };
in
{
  extraCollectors = [ "conntrack" ];
  extraLabels.role = "router";
  rules = import ./rules.nix { inherit network; };
  dashboards.network = import ./dashboard.nix { inherit network; };
}

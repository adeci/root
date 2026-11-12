# Monitoring agent settings for the router: its alert rules and dashboard, derived from the inventory.
inventory:
let
  network = import ./network.nix inventory;
in
{
  extraCollectors = [ "conntrack" ];
  extraLabels.role = "router";
  rules = import ./rules.nix { inherit network; };
  dashboards.network = import ./dashboard.nix { inherit network; };
}

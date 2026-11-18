# Monitoring agent settings for the router.
inventory:
let
  network = import ./network.nix inventory;
in
{
  extraCollectors = [
    "conntrack"
    "timex"
  ];
  extraLabels.role = "router";
  exporters = {
    kea-dhcp4 = 9547;
    unbound = 9167;
    smokeping = 9374;
    mikrotik = 9436;
    mikrotik-poe = 9437;
  };
  rules = import ./rules.nix network;
  dashboards.network = import ./dashboard network;
}

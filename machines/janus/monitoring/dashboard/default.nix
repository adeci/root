# The router's dashboard, its sections in page order.
network:
let
  ui = import ../../../../clan-services/monitoring/dashboards/lib.nix;
  queries = import ./queries.nix { inherit ui network; };
  section = file: import file { inherit ui network queries; };
in
ui.dashboard {
  uid = "atlas-network";
  title = "Network / Router";
  panels = map section [
    ./glance.nix
    ./gateway.nix
    ./interfaces.nix
    ./dhcp.nix
    ./dns.nix
    ./system.nix
    ./firewall.nix
    ./devices.nix
  ];
}

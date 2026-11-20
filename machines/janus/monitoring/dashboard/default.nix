# The router's dashboard, its sections in page order.
network:
let
  ui = import ../../../../clan-services/monitoring/dashboards/lib.nix;
  queries = import ./queries.nix network;
  section = file: import file { inherit ui network queries; };
in
ui.dashboard {
  uid = "atlas-network";
  title = "Network / Router";
  # A day, so overnight outages and changes still show in the morning.
  from = "now-24h";
  panels = map section [
    ./now.nix
    ./internet.nix
    ./devices.nix
    ./networks.nix
    ./clients.nix
    ./firewall.nix
    ./router.nix
  ];
}

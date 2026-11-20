{
  ui,
  network,
  queries,
}:
let
  inherit (queries) router named perVlan;
  inherit (network.interfaces) wan;

  bits =
    direction: interface:
    ''8 * rate(node_network_${direction}_bytes_total{${router}, device="${interface}"}[$__rate_interval])'';
  # Clients' view: down is what the router sends into a VLAN or takes from the internet.
  down = "sum by (network) (${named "internet" (bits "receive" wan)} or ${
    perVlan (vlan: bits "transmit" vlan.interface)
  })";
  up = "sum by (network) (${named "internet" (bits "transmit" wan)} or ${
    perVlan (vlan: bits "receive" vlan.interface)
  })";
  traffic = "${down} + ${up}";
in
ui.row {
  title = "Networks";
  collapsed = false;
  panels = [
    (ui.mergedTable {
      title = "Networks";
      description = "The internet via the WAN port, and each VLAN. Clients: holding an address from the router. Peak: the busiest moment in the picked range, beside its course.";
      w = 15;
      # The internet and each VLAN, plus the title and the header.
      h = builtins.length network.vlans + 3;
      joinBy = "network";
      sortBy = [
        {
          displayName = "Network";
          desc = false;
        }
      ];
      renamedColumns.network = "Network";
      firstColumns = [ "network" ];
      columns = [
        {
          name = "Clients";
          width = 80;
          expr = "max by (network) (${
            perVlan (
              vlan: ''kea_dhcp4_addresses_assigned_total{${router}, pool="", subnet_id="${toString vlan.id}"}''
            )
          })";
        }
        {
          name = "Down";
          width = 100;
          expr = down;
          unit = "bps";
        }
        {
          name = "Up";
          width = 100;
          expr = up;
          unit = "bps";
        }
        {
          name = "Peak";
          expr = traffic;
          unit = "bps";
          sparkline = ui.colours.traffic;
        }
      ];
    })
    (ui.statusHistory {
      title = "Traffic";
      description = "Down and up together. Brighter is busier.";
      w = 9;
      h = builtins.length network.vlans + 3;
      unit = "bps";
      threshold = ui.thresholds.trafficShades;
      targets = [ (ui.target traffic "{{network}}") ];
    })
  ];
}

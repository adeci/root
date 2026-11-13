{ ui, queries, ... }:
let
  inherit (queries) router subnetIds;

  leases =
    vlan: ''kea_dhcp4_addresses_assigned_total{${router},pool="",subnet_id="${toString vlan.id}"}'';
  poolUsage =
    vlan:
    ''100 * kea_dhcp4_addresses_assigned_total{${router},pool!="",subnet_id="${toString vlan.id}"} / kea_dhcp4_addresses_total{${router},pool!="",subnet_id="${toString vlan.id}"}'';
  received =
    operation:
    ''rate(kea_dhcp4_packets_received_total{${router},operation="${operation}"}[$__rate_interval])'';
  sent =
    operation:
    ''rate(kea_dhcp4_packets_sent_total{${router},operation="${operation}"}[$__rate_interval])'';
in
ui.row {
  title = "DHCP";
  panels = [
    (ui.statTargets {
      title = "DHCP Leases";
      w = 8;
      h = 8;
      threshold = ui.thresholds.neutral;
      targets = queries.vlanTargets leases;
      overrides = queries.vlanColours;
    })
    (ui.barGauge {
      title = "DHCP Pool Usage";
      w = 8;
      h = 8;
      unit = "percent";
      targets = queries.vlanTargets poolUsage;
    })
    (ui.timeseries {
      title = "DHCP Packet Activity";
      w = 8;
      h = 8;
      unit = "pps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target (received "discover") "discover")
        (ui.target (received "request") "request")
        (ui.target (sent "ack") "ack")
        (ui.target (sent "nak") "nak")
      ];
      overrides = [
        (ui.colorOverride "discover" "blue")
        (ui.colorOverride "request" "yellow")
        (ui.colorOverride "ack" "green")
        (ui.colorOverride "nak" "red")
      ];
    })

    (ui.timeseries {
      title = "DHCP Issues";
      w = 12;
      h = 6;
      targets = [
        (ui.target ''sum(kea_dhcp4_addresses_declined_total{${router},pool="",subnet_id=~"${subnetIds}"})'' "declined")
        (ui.target ''sum(kea_dhcp4_reservation_conflicts_total{${router},subnet_id=~"${subnetIds}"})'' "reservation conflicts")
        (ui.target ''sum(kea_dhcp4_allocations_failed_total{${router},subnet_id=~"${subnetIds}"}) or vector(0)'' "allocation failures")
      ];
    })
  ];
}

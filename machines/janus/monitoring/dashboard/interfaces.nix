{
  ui,
  network,
  queries,
}:
let
  inherit (queries) router bps total;
  inherit (network.interfaces) wan lan mgmt;

  faults =
    kind: direction:
    ''rate(node_network_${direction}_${kind}_total{${router},device=~"${queries.routedInterfaces}"}[$__rate_interval])'';
  ports = builtins.concatStringsSep "|" [
    wan
    lan
    mgmt
  ];
in
ui.row {
  title = "Interfaces / VLANs";
  panels = [
    (ui.timeseries {
      title = "Interface Throughput";
      w = 12;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target (bps (total wan)) "wan")
        (ui.target (bps (total lan)) "lan trunk")
      ]
      ++ queries.vlanTargets (vlan: bps (total vlan.interface));
      overrides = [
        (ui.colorOverride "wan" "blue")
        (ui.colorOverride "lan trunk" "super-light-blue")
      ]
      ++ queries.vlanColours;
    })
    (ui.timeseries {
      title = "Interface Faults";
      w = 12;
      h = 8;
      unit = "pps";
      targets = [
        (ui.target "sum(${faults "drop" "receive"} + ${faults "drop" "transmit"})" "drops")
        (ui.target "sum(${faults "errs" "receive"} + ${faults "errs" "transmit"})" "errors")
      ];
      overrides = [
        (ui.colorOverride "drops" "yellow")
        (ui.colorOverride "errors" "red")
      ];
    })

    (ui.stat {
      title = "Link status";
      w = 4;
      h = 4;
      expr = ''min(node_network_carrier{${router},device=~"${ports}"})'';
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.barGauge {
      title = "Link speed";
      w = 8;
      h = 6;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target ''clamp_min(8 * node_network_speed_bytes{${router},device=~"${ports}"}, 0)'' "{{device}}")
      ];
    })
  ];
}

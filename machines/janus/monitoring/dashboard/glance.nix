{
  ui,
  network,
  queries,
}:
let
  inherit (queries)
    router
    bps
    received
    transmitted
    internetLatency
    ;
  inherit (network.interfaces) wan;

  faultsInRange =
    kind: direction:
    ''increase(node_network_${direction}_${kind}_total{${router},device=~"${queries.routedInterfaces}"}[$__range])'';
  linkFaults = ''
    sum(
      ${faultsInRange "errs" "receive"}
      + ${faultsInRange "errs" "transmit"}
      + ${faultsInRange "drop" "receive"}
      + ${faultsInRange "drop" "transmit"}
    )
  '';
in
ui.row {
  title = "At a Glance";
  collapsed = false;
  panels = [
    (ui.stat {
      title = "Internet";
      w = 3;
      h = 4;
      expr = ''(min(janus_network_probe_up{group=~"wan|internet"}) or vector(0)) * (max(janus_dns_probe_up) or vector(0))'';
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      title = "Latency";
      w = 3;
      h = 4;
      unit = "ms";
      expr = internetLatency "0.95";
      threshold = ui.thresholds.latencyMs;
      sparkline = true;
    })
    (ui.stat {
      title = "Loss";
      w = 3;
      h = 4;
      unit = "percent";
      expr = queries.internetLoss;
      threshold = ui.thresholds.packetLossPercent;
      sparkline = true;
    })
    (ui.stat {
      title = "Faults";
      w = 3;
      h = 4;
      expr = linkFaults;
      threshold = ui.thresholds.goodWhenZero;
      sparkline = true;
    })
    (ui.stat {
      title = "Down";
      w = 3;
      h = 4;
      unit = "bps";
      expr = bps (received wan);
      threshold = ui.thresholds.neutral;
      fixedColor = "blue";
      sparkline = true;
    })
    (ui.stat {
      title = "Up";
      w = 3;
      h = 4;
      unit = "bps";
      expr = bps (transmitted wan);
      threshold = ui.thresholds.neutral;
      fixedColor = "orange";
      sparkline = true;
    })
    (ui.stat {
      title = "Clients";
      w = 3;
      h = 4;
      expr = ''sum(kea_dhcp4_addresses_assigned_total{${router},pool="",subnet_id=~"${queries.subnetIds}"})'';
      threshold = ui.thresholds.neutral;
      sparkline = true;
    })
    (ui.stat {
      title = "CPU";
      w = 3;
      h = 4;
      unit = "percent";
      expr = queries.cpu;
      threshold = ui.thresholds.pressure;
      sparkline = true;
    })

    (ui.timeseries {
      title = "WAN Throughput";
      w = 8;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target (bps (received wan)) "download")
        (ui.target (bps (transmitted wan)) "upload")
      ];
      overrides = [
        (ui.colorOverride "download" "blue")
        (ui.colorOverride "upload" "orange")
      ];
    })
    (ui.timeseries {
      title = "Traffic by Network";
      w = 8;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = queries.vlanTargets (vlan: bps (queries.total vlan.interface));
      overrides = queries.vlanColours;
    })
    (ui.timeseries {
      title = "Internet Latency Percentiles";
      w = 8;
      h = 8;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target (internetLatency "0.50") "p50")
        (ui.target (internetLatency "0.90") "p90")
        (ui.target (internetLatency "0.95") "p95")
        (ui.target (internetLatency "0.99") "p99")
      ];
      overrides = [
        (ui.colorOverride "p50" "green")
        (ui.colorOverride "p90" "blue")
        (ui.colorOverride "p95" "orange")
        (ui.colorOverride "p99" "red")
      ];
    })
  ];
}

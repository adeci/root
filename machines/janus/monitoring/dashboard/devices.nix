{
  ui,
  network,
  queries,
}:
let
  inherit (queries) router;
  mikrotik = ''${router},job="mikrotik"'';

  # Over the appliance ports on known cables, in parentheses so it combines like one selector.
  onCabledPorts = query: "(${network.onPorts network.cabledPorts query})";
  cabledRate =
    metric: onCabledPorts (ports: "rate(${metric}{${mikrotik},${ports}}[$__rate_interval])");
  errors = ''
    sum by (name, interface) (
      ${cabledRate "mikrotik_interface_rx_error"}
      + ${cabledRate "mikrotik_interface_tx_error"}
    )
  '';
  drops = ''
    sum by (name, interface) (
      ${cabledRate "mikrotik_interface_rx_drop"}
      + ${cabledRate "mikrotik_interface_tx_drop"}
    )
  '';
  linkDowns = "sum by (name, interface) (${cabledRate "mikrotik_interface_link_downs"})";

  health = ''
    label_replace(janus_network_probe_up{${router},group="routeros"}, "name", "$1", "target", "(.*)")
    * on(name) label_replace(mikrotik_scrape_collector_success{${mikrotik}}, "name", "$1", "device", "(.*)")
    * on(name) janus_routeros_health_scrape_success{${router}}
  '';
  temperature = ''
    max by (name) (janus_routeros_temperature_celsius{${router}})
  '';

  # mikrotik_monitor_rate is in Mb/s; SFP+ ports should link at 10 Gb/s, copper ports at 1 Gb/s.
  linksDown = onCabledPorts (ports: "mikrotik_monitor_status{${mikrotik},${ports}} == 0");
  slowFibreLinks = onCabledPorts (
    ports: ''mikrotik_monitor_rate{${mikrotik},${ports},interface=~"sfp-sfpplus.+"} < 10000''
  );
  slowCopperLinks = onCabledPorts (
    ports: ''mikrotik_monitor_rate{${mikrotik},${ports},interface=~"ether.+"} < 1000''
  );
  linkRates = onCabledPorts (ports: "mikrotik_monitor_rate{${mikrotik},${ports}}");
  linkProblems = ''
    (count(${linksDown}) or vector(0))
    + (count(${slowFibreLinks}) or vector(0))
    + (count(${slowCopperLinks}) or vector(0))
  '';
in
ui.row {
  title = "Network Devices";
  panels = [
    (ui.barGauge {
      title = "Device Health";
      w = 6;
      h = 6;
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
      displayMode = "basic";
      targets = [ (ui.target health "{{name}}") ];
    })
    (ui.barGauge {
      title = "Heat";
      w = 6;
      h = 6;
      unit = "celsius";
      threshold = ui.thresholds.networkDeviceTemperatureC;
      displayMode = "basic";
      targets = [ (ui.target temperature "{{name}}") ];
    })
    (ui.stat {
      title = "Link Health";
      w = 6;
      h = 6;
      expr = "1 - clamp_max(${linkProblems}, 1)";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.statTargets {
      title = "Latency";
      w = 6;
      h = 6;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target ''1000 * janus_network_probe_latency_seconds{${router},group="routeros"}'' "{{target}}")
      ];
    })

    (ui.barGauge {
      title = "Uplink Negotiation";
      w = 12;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.linkSpeedBps;
      displayMode = "basic";
      targets = [ (ui.target "1000000 * ${linkRates}" "{{name}} {{interface}}") ];
    })
    (ui.barGauge {
      title = "CPU";
      w = 6;
      h = 8;
      unit = "percent";
      displayMode = "basic";
      targets = [ (ui.target "avg by (name) (mikrotik_system_cpu_load{${mikrotik}})" "{{name}}") ];
    })
    (ui.barGauge {
      title = "Memory";
      w = 6;
      h = 8;
      unit = "percent";
      displayMode = "basic";
      targets = [
        (ui.target "100 * (1 - mikrotik_system_free_memory{${mikrotik}} / mikrotik_system_total_memory{${mikrotik}})" "{{name}}")
      ];
    })

    (ui.stat {
      title = "PoE Total";
      w = 6;
      h = 6;
      unit = "watt";
      expr = ''sum(mikrotik_poe_wattage{${router},job="mikrotik-poe"}) or vector(0)'';
      threshold = ui.thresholds.neutral;
      fixedColor = "blue";
      sparkline = true;
    })
    (ui.timeseries {
      title = "Uplink Fault Trend";
      w = 18;
      h = 6;
      unit = "pps";
      threshold = ui.thresholds.goodWhenZero;
      targets = [
        (ui.target "sum(${errors}) or vector(0)" "errors")
        (ui.target "sum(${drops}) or vector(0)" "drops")
        (ui.target "sum(${linkDowns}) or vector(0)" "link downs")
      ];
      overrides = [
        (ui.colorOverride "errors" "red")
        (ui.colorOverride "drops" "orange")
        (ui.colorOverride "link downs" "yellow")
      ];
    })
  ];
}

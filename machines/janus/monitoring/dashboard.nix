# The router's dashboard: internet quality, traffic per VLAN, DHCP, DNS, firewall and the RouterOS devices.
{ network }:
let
  ui = import ../../../clan-services/monitoring/dashboards/lib.nix;

  janus = ''instance="${network.instance}"'';
  unbound = ''${janus},job="unbound"'';
  smokeping = ''${janus},job="smokeping"'';
  internetQuality = ''${smokeping},group="internet"'';
  inherit (network) wan lan vlans;

  oneOf = builtins.concatStringsSep "|";
  routedInterfaces = oneOf (
    [
      wan
      lan
    ]
    ++ map (vlan: vlan.interface) vlans
  );
  linkInterfaces = oneOf [
    wan
    lan
    network.mgmt
  ];
  subnetIds = oneOf (map (vlan: toString vlan.id) vlans);

  refIds = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  vlanPalette = [
    "green"
    "yellow"
    "orange"
    "purple"
    "light-red"
    "cyan"
    "dark-green"
    "dark-yellow"
  ];
  vlanCount = builtins.length vlans;
  vlanColour =
    index:
    builtins.elemAt vlanPalette (
      index - index / builtins.length vlanPalette * builtins.length vlanPalette
    );

  # One target per VLAN named after it, with refIds from the given position on.
  vlanTargets =
    firstRefId: query:
    builtins.genList (
      index:
      let
        vlan = builtins.elemAt vlans index;
      in
      ui.target (builtins.substring (firstRefId + index) 1 refIds) (query vlan) vlan.name
    ) vlanCount;

  # Every panel gives a VLAN the same colour.
  vlanColours = builtins.genList (
    index: ui.colorOverride (builtins.elemAt vlans index).name (vlanColour index)
  ) vlanCount;

  rx =
    device: ''rate(node_network_receive_bytes_total{${janus},device="${device}"}[$__rate_interval])'';
  tx =
    device: ''rate(node_network_transmit_bytes_total{${janus},device="${device}"}[$__rate_interval])'';
  bps = expr: "8 * (${expr})";
  lossPercent = expr: "100 * (${expr})";
  total = device: "${rx device} + ${tx device}";

  faultExpr =
    kind: direction:
    ''rate(node_network_${direction}_${kind}_total{${janus},device=~"${routedInterfaces}"}[$__rate_interval])'';
  faultIncrease =
    kind: direction:
    ''increase(node_network_${direction}_${kind}_total{${janus},device=~"${routedInterfaces}"}[$__range])'';

  linkFaultsInRange = ''
    sum(
      ${faultIncrease "errs" "receive"}
      + ${faultIncrease "errs" "transmit"}
      + ${faultIncrease "drop" "receive"}
      + ${faultIncrease "drop" "transmit"}
    )
  '';

  cpu = ''100 * (1 - avg(rate(node_cpu_seconds_total{${janus},mode="idle"}[$__rate_interval])))'';
  memory = "100 * (1 - node_memory_MemAvailable_bytes{${janus}} / node_memory_MemTotal_bytes{${janus}})";
  conntrack = "100 * node_nf_conntrack_entries{${janus}} / node_nf_conntrack_entries_limit{${janus}}";
  loadPerCore = ''node_load1{${janus}} / scalar(count(count by(cpu) (node_cpu_seconds_total{${janus},mode="idle"})))'';
  rootDisk = ''100 * (1 - node_filesystem_avail_bytes{${janus},mountpoint="/"} / node_filesystem_size_bytes{${janus},mountpoint="/"})'';
  diskDevices = "loop.*|ram.*|zram.*";
  diskBusy = ''100 * rate(node_disk_io_time_seconds_total{${janus},device!~"${diskDevices}"}[$__rate_interval])'';
  diskWrites = ''sum(rate(node_disk_written_bytes_total{${janus},device!~"${diskDevices}"}[$__rate_interval]))'';
  ioWaiting = "100 * rate(node_pressure_io_waiting_seconds_total{${janus}}[$__rate_interval])";
  firewall = ''${janus},family="inet",table="filter"'';
  mikrotik = ''${janus},job="mikrotik"'';
  mikrotikPoe = ''${janus},job="mikrotik-poe"'';

  # Queries over the RouterOS ports on known cables, wrapped so they combine like one selector.
  cabledPorts = query: "(${network.onPorts network.cabledPorts query})";
  cabledRate = metric: cabledPorts (ports: "rate(${metric}{${mikrotik},${ports}}[$__rate_interval])");
  cabledErrors = ''
    sum by (name, interface) (
      ${cabledRate "mikrotik_interface_rx_error"}
      + ${cabledRate "mikrotik_interface_tx_error"}
    )
  '';
  cabledDrops = ''
    sum by (name, interface) (
      ${cabledRate "mikrotik_interface_rx_drop"}
      + ${cabledRate "mikrotik_interface_tx_drop"}
    )
  '';
  cabledLinkDowns = "sum by (name, interface) (${cabledRate "mikrotik_interface_link_downs"})";
  routerosTemp = ''
    max by (name) (janus_routeros_temperature_celsius{${janus}})
  '';
  routerosHealth = ''
    label_replace(janus_network_probe_up{${janus},group="routeros"}, "name", "$1", "target", "(.*)")
    * on(name) label_replace(mikrotik_scrape_collector_success{${mikrotik}}, "name", "$1", "device", "(.*)")
    * on(name) janus_routeros_health_scrape_success{${janus}}
  '';
  # mikrotik_monitor_rate is in Mb/s; SFP+ ports should link at 10 Gb/s, copper ports at 1 Gb/s.
  linksDown = cabledPorts (ports: "mikrotik_monitor_status{${mikrotik},${ports}} == 0");
  slowFibreLinks = cabledPorts (
    ports: ''mikrotik_monitor_rate{${mikrotik},${ports},interface=~"sfp-sfpplus.+"} < 10000''
  );
  slowCopperLinks = cabledPorts (
    ports: ''mikrotik_monitor_rate{${mikrotik},${ports},interface=~"ether.+"} < 1000''
  );
  linkRates = cabledPorts (ports: "mikrotik_monitor_rate{${mikrotik},${ports}}");
  routerosLinkProblems = ''
    (count(${linksDown}) or vector(0))
    + (count(${slowFibreLinks}) or vector(0))
    + (count(${slowCopperLinks}) or vector(0))
  '';
  routerosLinkHealthy = "1 - clamp_max(${routerosLinkProblems}, 1)";

  systemdActive =
    unit: ''max(node_systemd_unit_state{${janus},name="${unit}",state="active"}) or vector(0)'';
  failedUnits = ''sum(node_systemd_unit_state{${janus},state="failed"} == 1) or vector(0)'';
  systemDegraded = "(1 - max(node_systemd_system_running{${janus}})) or vector(1)";
  textfilesFresh =
    files:
    ''(max(time() - node_textfile_mtime_seconds{${janus},file=~"${files}"}) < bool 300) or vector(0)'';
  firewallCountersFresh = textfilesFresh ".*/janus-firewall-counters.prom";
  serviceProblemCount = "(${failedUnits}) + (${systemDegraded}) + (1 - (${firewallCountersFresh}))";
  firewallHealthy = "(${systemdActive "nftables.service"}) * (${firewallCountersFresh})";
  telemetryHealthy = "(min(up{${janus}}) or vector(0)) * (${textfilesFresh ".*"})";
  cpuTemp = ''max(node_hwmon_temp_celsius{${janus},chip="platform_coretemp_0"})'';
  nvmeTemp = ''max(node_hwmon_temp_celsius{${janus},chip="nvme_nvme0"})'';
  diskBusyMax = "max(${diskBusy}) or vector(0)";

  dhcpAssigned =
    vlan: ''kea_dhcp4_addresses_assigned_total{${janus},pool="",subnet_id="${toString vlan.id}"}'';
  dhcpPoolUsage =
    vlan:
    ''100 * kea_dhcp4_addresses_assigned_total{${janus},pool!="",subnet_id="${toString vlan.id}"} / kea_dhcp4_addresses_total{${janus},pool!="",subnet_id="${toString vlan.id}"}'';

  unboundRate = metric: "sum(rate(${metric}{${unbound}}[$__rate_interval])) or vector(0)";
  unboundCacheHitRatio = ''
    (
      sum(rate(unbound_cache_hits_total{${unbound}}[$__rate_interval]))
      /
      clamp_min(
        sum(rate(unbound_cache_hits_total{${unbound}}[$__rate_interval]))
        + sum(rate(unbound_cache_misses_total{${unbound}}[$__rate_interval])),
        0.001
      )
    ) or vector(0)
  '';
  unboundLatency = quantile: ''
    (1000 * histogram_quantile(${quantile}, sum by (le) (rate(unbound_response_time_seconds_bucket{${unbound}}[$__rate_interval]))))
    or vector(0)
  '';

  smokepingLatency = quantile: selector: ''
    (1000 * histogram_quantile(${quantile}, sum by (le) (rate(smokeping_response_duration_seconds_bucket{${selector}}[$__rate_interval]))))
    or vector(0)
  '';
  smokepingLoss = selector: ''
    100 * (
      1 - (
        sum(rate(smokeping_response_duration_seconds_count{${selector}}[$__rate_interval]))
        /
        clamp_min(sum(rate(smokeping_requests_total{${selector}}[$__rate_interval])), 0.001)
      )
    )
  '';

  gatewayPanels = [
    (ui.timeseries {
      id = 101;
      title = "Gateway + Internet Latency";
      x = 0;
      y = 15;
      w = 8;
      h = 8;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "A" ''1000 * janus_network_probe_latency_seconds{group=~"wan|internet"}'' "{{target}}")
      ];
      overrides = [
        (ui.colorOverride "wan_gateway" "green")
        (ui.colorOverride "cloudflare_dns" "blue")
        (ui.colorOverride "google_dns" "orange")
      ];
    })
    (ui.timeseries {
      id = 102;
      title = "Internet Latency Spread";
      x = 8;
      y = 15;
      w = 8;
      h = 8;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "A"
          "(${smokepingLatency "0.95" internetQuality}) - (${smokepingLatency "0.50" internetQuality})"
          "p95 - p50"
        )
        (ui.target "B"
          "(${smokepingLatency "0.99" internetQuality}) - (${smokepingLatency "0.50" internetQuality})"
          "p99 - p50"
        )
      ];
      overrides = [
        (ui.colorOverride "p95 - p50" "orange")
        (ui.colorOverride "p99 - p50" "red")
      ];
    })
    (ui.timeseries {
      id = 103;
      title = "Gateway + Internet Packet Loss";
      x = 16;
      y = 15;
      w = 8;
      h = 8;
      unit = "percent";
      threshold = ui.thresholds.packetLossPercent;
      targets = [
        (ui.target "A" (lossPercent ''janus_network_probe_packet_loss_ratio{target="wan_gateway"}'')
          "wan gateway"
        )
        (ui.target "B" (smokepingLoss internetQuality) "internet")
      ];
      overrides = [
        (ui.colorOverride "wan gateway" "green")
        (ui.colorOverride "internet" "red")
      ];
    })
  ];

  interfacePanels = [
    (ui.timeseries {
      id = 201;
      title = "Interface Throughput";
      x = 0;
      y = 24;
      w = 12;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A" (bps (total wan)) "wan")
        (ui.target "B" (bps (total lan)) "lan trunk")
      ]
      ++ vlanTargets 2 (vlan: bps (total vlan.interface));
      overrides = [
        (ui.colorOverride "wan" "blue")
        (ui.colorOverride "lan trunk" "super-light-blue")
      ]
      ++ vlanColours;
    })
    (ui.timeseries {
      id = 202;
      title = "Interface Faults";
      x = 12;
      y = 24;
      w = 12;
      h = 8;
      unit = "pps";
      targets = [
        (ui.target "A" "sum(${faultExpr "drop" "receive"} + ${faultExpr "drop" "transmit"})" "drops")
        (ui.target "B" "sum(${faultExpr "errs" "receive"} + ${faultExpr "errs" "transmit"})" "errors")
      ];
      overrides = [
        (ui.colorOverride "drops" "yellow")
        (ui.colorOverride "errors" "red")
      ];
    })
    (ui.stat {
      id = 203;
      title = "Link status";
      x = 0;
      y = 32;
      w = 4;
      h = 4;
      expr = ''min(node_network_carrier{${janus},device=~"${linkInterfaces}"})'';
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.barGauge {
      id = 204;
      title = "Link speed";
      x = 4;
      y = 32;
      w = 8;
      h = 6;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A" ''clamp_min(8 * node_network_speed_bytes{${janus},device=~"${linkInterfaces}"}, 0)''
          "{{device}}"
        )
      ];
    })
  ];

  dhcpPanels = [
    (ui.statTargets {
      id = 301;
      title = "DHCP Leases";
      x = 0;
      y = 40;
      w = 8;
      h = 8;
      threshold = ui.thresholds.neutral;
      targets = vlanTargets 0 dhcpAssigned;
      overrides = vlanColours;
    })
    (ui.barGauge {
      id = 302;
      title = "DHCP Pool Usage";
      x = 8;
      y = 40;
      w = 8;
      h = 8;
      unit = "percent";
      targets = vlanTargets 0 dhcpPoolUsage;
    })
    (ui.timeseries {
      id = 303;
      title = "DHCP Packet Activity";
      x = 16;
      y = 40;
      w = 8;
      h = 8;
      unit = "pps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A"
          ''rate(kea_dhcp4_packets_received_total{${janus},operation="discover"}[$__rate_interval])''
          "discover"
        )
        (ui.target "B"
          ''rate(kea_dhcp4_packets_received_total{${janus},operation="request"}[$__rate_interval])''
          "request"
        )
        (ui.target "C" ''rate(kea_dhcp4_packets_sent_total{${janus},operation="ack"}[$__rate_interval])''
          "ack"
        )
        (ui.target "D" ''rate(kea_dhcp4_packets_sent_total{${janus},operation="nak"}[$__rate_interval])''
          "nak"
        )
      ];
      overrides = [
        (ui.colorOverride "discover" "blue")
        (ui.colorOverride "request" "yellow")
        (ui.colorOverride "ack" "green")
        (ui.colorOverride "nak" "red")
      ];
    })
    (ui.timeseries {
      id = 304;
      title = "DHCP Issues";
      x = 0;
      y = 48;
      w = 12;
      h = 6;
      targets = [
        (ui.target "A"
          ''sum(kea_dhcp4_addresses_declined_total{${janus},pool="",subnet_id=~"${subnetIds}"})''
          "declined"
        )
        (ui.target "B" ''sum(kea_dhcp4_reservation_conflicts_total{${janus},subnet_id=~"${subnetIds}"})''
          "reservation conflicts"
        )
        (ui.target "C"
          ''sum(kea_dhcp4_allocations_failed_total{${janus},subnet_id=~"${subnetIds}"}) or vector(0)''
          "allocation failures"
        )
      ];
    })
  ];

  dnsPanels = [
    (ui.timeseries {
      id = 401;
      title = "DNS Resolution";
      x = 0;
      y = 56;
      w = 8;
      h = 7;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "A" "1000 * janus_dns_probe_latency_seconds" "google.com A via 127.0.0.1")
      ];
    })
    (ui.stat {
      id = 402;
      title = "DNS probe status";
      x = 8;
      y = 56;
      w = 4;
      h = 4;
      expr = "max(janus_dns_probe_up) or vector(0)";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      id = 403;
      title = "Unbound status";
      x = 12;
      y = 56;
      w = 4;
      h = 4;
      expr = "max(unbound_up{${unbound}}) or vector(0)";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.timeseries {
      id = 404;
      title = "Unbound Queries";
      x = 16;
      y = 56;
      w = 8;
      h = 7;
      unit = "ops";
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target "A" (unboundRate "unbound_queries_total") "queries") ];
    })
    (ui.timeseries {
      id = 405;
      title = "Cache Hit Ratio";
      x = 0;
      y = 63;
      w = 8;
      h = 7;
      unit = "percentunit";
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target "A" unboundCacheHitRatio "hits / total") ];
    })
    (ui.timeseries {
      id = 406;
      title = "RCODE Rates";
      x = 8;
      y = 63;
      w = 8;
      h = 7;
      unit = "ops";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A"
          ''sum by (rcode) (rate(unbound_answer_rcodes_total{${unbound},rcode=~"NOERROR|NXDOMAIN|SERVFAIL"}[$__rate_interval])) or on() vector(0)''
          "{{rcode}}"
        )
      ];
    })
    (ui.timeseries {
      id = 407;
      title = "Query Type Rates";
      x = 16;
      y = 63;
      w = 8;
      h = 7;
      unit = "ops";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A"
          ''sum by (type) (rate(unbound_query_types_total{${unbound},type=~"A|AAAA|PTR|SRV"}[$__rate_interval])) or on() vector(0)''
          "{{type}}"
        )
      ];
    })
    (ui.timeseries {
      id = 408;
      title = "Response Latency";
      x = 0;
      y = 70;
      w = 8;
      h = 7;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "A" (unboundLatency "0.50") "p50")
        (ui.target "B" (unboundLatency "0.95") "p95")
      ];
    })
    (ui.timeseries {
      id = 409;
      title = "Request List Pressure";
      x = 8;
      y = 70;
      w = 8;
      h = 7;
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A" "sum(unbound_request_list_current_user{${unbound}}) or vector(0)" "current user")
        (ui.target "B" "sum(unbound_request_list_current_all{${unbound}}) or vector(0)" "current all")
        (ui.target "C" (unboundRate "unbound_request_list_exceeded_total") "dropped/s")
        (ui.target "D" (unboundRate "unbound_request_list_overwritten_total") "overwritten/s")
      ];
    })
    (ui.timeseries {
      id = 410;
      title = "Unbound Memory";
      x = 16;
      y = 70;
      w = 8;
      h = 7;
      unit = "bytes";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A" "sum by (cache) (unbound_memory_caches_bytes{${unbound}}) or on() vector(0)"
          "cache {{cache}}"
        )
        (ui.target "B" "sum by (module) (unbound_memory_modules_bytes{${unbound}}) or on() vector(0)"
          "module {{module}}"
        )
      ];
    })
  ];

  routerSystemPanels = [
    (ui.stat {
      id = 520;
      title = "DHCP";
      x = 0;
      y = 80;
      w = 3;
      h = 4;
      expr = systemdActive "kea-dhcp4-server.service";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      id = 521;
      title = "DNS";
      x = 3;
      y = 80;
      w = 3;
      h = 4;
      expr = systemdActive "unbound.service";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      id = 522;
      title = "Firewall";
      x = 6;
      y = 80;
      w = 3;
      h = 4;
      expr = firewallHealthy;
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      id = 523;
      title = "Tailscale";
      x = 9;
      y = 80;
      w = 3;
      h = 4;
      expr = systemdActive "tailscaled.service";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      id = 524;
      title = "Telemetry";
      x = 12;
      y = 80;
      w = 3;
      h = 4;
      expr = telemetryHealthy;
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      id = 525;
      title = "Problems";
      x = 15;
      y = 80;
      w = 3;
      h = 4;
      expr = serviceProblemCount;
      threshold = ui.thresholds.goodWhenZero;
    })
    (ui.stat {
      id = 526;
      title = "CPU Temp";
      x = 18;
      y = 80;
      w = 3;
      h = 4;
      unit = "celsius";
      expr = cpuTemp;
      threshold = ui.thresholds.temperatureC;
    })
    (ui.stat {
      id = 527;
      title = "NVMe Temp";
      x = 21;
      y = 80;
      w = 3;
      h = 4;
      unit = "celsius";
      expr = nvmeTemp;
      threshold = ui.thresholds.temperatureC;
    })
    (ui.barGauge {
      id = 501;
      title = "Router Resources";
      x = 0;
      y = 84;
      w = 8;
      h = 7;
      unit = "percent";
      targets = [
        (ui.target "A" cpu "cpu")
        (ui.target "B" memory "memory")
        (ui.target "C" conntrack "firewall states")
        (ui.target "D" rootDisk "root disk")
      ];
      overrides = [
        (ui.colorOverride "cpu" "blue")
        (ui.colorOverride "memory" "yellow")
        (ui.colorOverride "firewall states" "green")
        (ui.colorOverride "root disk" "orange")
      ];
    })
    (ui.stat {
      id = 502;
      title = "Load Per Core";
      x = 8;
      y = 84;
      w = 4;
      h = 7;
      expr = loadPerCore;
      threshold = ui.thresholds.pressure;
      sparkline = true;
    })
    (ui.stat {
      id = 528;
      title = "Disk Busy";
      x = 12;
      y = 84;
      w = 4;
      h = 7;
      unit = "percent";
      expr = diskBusyMax;
      threshold = ui.thresholds.ioPressure;
      sparkline = true;
    })
    (ui.stat {
      id = 529;
      title = "IO Wait";
      x = 16;
      y = 84;
      w = 4;
      h = 7;
      unit = "percent";
      expr = ioWaiting;
      threshold = ui.thresholds.ioPressure;
      sparkline = true;
    })
    (ui.stat {
      id = 530;
      title = "Disk Writes";
      x = 20;
      y = 84;
      w = 4;
      h = 7;
      unit = "Bps";
      expr = diskWrites;
      threshold = ui.thresholds.neutral;
      fixedColor = "blue";
      sparkline = true;
    })
  ];

  firewallPanels = [
    (ui.timeseries {
      id = 503;
      title = "Firewall Drops";
      x = 0;
      y = 93;
      w = 8;
      h = 8;
      unit = "pps";
      threshold = ui.thresholds.goodWhenZero;
      targets = [
        (ui.target "A"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter="input_drop_default"}[$__rate_interval])) or on() vector(0)''
          "input default deny"
        )
        (ui.target "B"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter="forward_drop_default"}[$__rate_interval])) or on() vector(0)''
          "forward default deny"
        )
        (ui.target "C"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter="input_drop_invalid"}[$__rate_interval])) or on() vector(0)''
          "input invalid"
        )
        (ui.target "D"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter="forward_drop_invalid"}[$__rate_interval])) or on() vector(0)''
          "forward invalid"
        )
      ];
      overrides = [
        (ui.colorOverride "input default deny" "red")
        (ui.colorOverride "forward default deny" "orange")
        (ui.colorOverride "input invalid" "purple")
        (ui.colorOverride "forward invalid" "blue")
      ];
    })
    (ui.timeseries {
      id = 504;
      title = "Firewall Decisions";
      x = 8;
      y = 93;
      w = 16;
      h = 8;
      unit = "pps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter="forward_accept_trusted"}[$__rate_interval])) or on() vector(0)''
          "trusted forward"
        )
        (ui.target "B"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter=~"forward_accept_.+_to_wan"}[$__rate_interval])) or on() vector(0)''
          "internet-only wan"
        )
        (ui.target "C"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter="input_accept_dhcp_dns"}[$__rate_interval])) or on() vector(0)''
          "local dns/dhcp"
        )
        (ui.target "D"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},counter=~"input_accept_ssh_admin|input_accept_tailnet_admin|input_accept_tailscale_direct_udp|forward_accept_tailscale_to_local"}[$__rate_interval])) or on() vector(0)''
          "admin/tailscale"
        )
        (ui.target "E"
          ''sum(rate(janus_firewall_counter_packets_total{${firewall},action="drop"}[$__rate_interval])) or on() vector(0)''
          "dropped"
        )
      ];
      overrides = [
        (ui.colorOverride "trusted forward" "green")
        (ui.colorOverride "internet-only wan" "yellow")
        (ui.colorOverride "local dns/dhcp" "blue")
        (ui.colorOverride "admin/tailscale" "purple")
        (ui.colorOverride "dropped" "red")
      ];
    })
    (ui.logs {
      id = 506;
      title = "Recent Firewall Drop Logs";
      x = 0;
      y = 102;
      w = 24;
      h = 10;
      expr = ''{${janus},transport="kernel"} |= "janus-fw "'';
    })
  ];

  devicePanels = [
    (ui.barGauge {
      id = 601;
      title = "Device Health";
      x = 0;
      y = 114;
      w = 6;
      h = 6;
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
      displayMode = "basic";
      targets = [ (ui.target "A" routerosHealth "{{name}}") ];
    })
    (ui.barGauge {
      id = 605;
      title = "Heat";
      x = 6;
      y = 114;
      w = 6;
      h = 6;
      unit = "celsius";
      threshold = ui.thresholds.networkDeviceTemperatureC;
      displayMode = "basic";
      targets = [ (ui.target "A" routerosTemp "{{name}}") ];
    })
    (ui.stat {
      id = 612;
      title = "Link Health";
      x = 12;
      y = 114;
      w = 6;
      h = 6;
      expr = routerosLinkHealthy;
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.statTargets {
      id = 608;
      title = "Latency";
      x = 18;
      y = 114;
      w = 6;
      h = 6;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "A" ''1000 * janus_network_probe_latency_seconds{${janus},group="routeros"}''
          "{{target}}"
        )
      ];
    })
    (ui.barGauge {
      id = 609;
      title = "Uplink Negotiation";
      x = 0;
      y = 121;
      w = 12;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.linkSpeedBps;
      displayMode = "basic";
      targets = [
        (ui.target "A" "1000000 * ${linkRates}" "{{name}} {{interface}}")
      ];
    })
    (ui.barGauge {
      id = 606;
      title = "CPU";
      x = 12;
      y = 121;
      w = 6;
      h = 8;
      unit = "percent";
      displayMode = "basic";
      targets = [
        (ui.target "A" "avg by (name) (mikrotik_system_cpu_load{${mikrotik}})" "{{name}}")
      ];
    })
    (ui.barGauge {
      id = 607;
      title = "Memory";
      x = 18;
      y = 121;
      w = 6;
      h = 8;
      unit = "percent";
      displayMode = "basic";
      targets = [
        (ui.target "A"
          "100 * (1 - mikrotik_system_free_memory{${mikrotik}} / mikrotik_system_total_memory{${mikrotik}})"
          "{{name}}"
        )
      ];
    })
    (ui.stat {
      id = 611;
      title = "PoE Total";
      x = 0;
      y = 130;
      w = 6;
      h = 6;
      unit = "watt";
      expr = "sum(mikrotik_poe_wattage{${mikrotikPoe}}) or vector(0)";
      threshold = ui.thresholds.neutral;
      fixedColor = "blue";
      sparkline = true;
    })
    (ui.timeseries {
      id = 610;
      title = "Uplink Fault Trend";
      x = 6;
      y = 130;
      w = 18;
      h = 6;
      unit = "pps";
      threshold = ui.thresholds.goodWhenZero;
      targets = [
        (ui.target "A" "sum(${cabledErrors}) or vector(0)" "errors")
        (ui.target "B" "sum(${cabledDrops}) or vector(0)" "drops")
        (ui.target "C" "sum(${cabledLinkDowns}) or vector(0)" "link downs")
      ];
      overrides = [
        (ui.colorOverride "errors" "red")
        (ui.colorOverride "drops" "orange")
        (ui.colorOverride "link downs" "yellow")
      ];
    })
  ];
in
ui.dashboard {
  uid = "atlas-network";
  title = "Network / Router";
  panels = [
    (ui.row {
      id = 0;
      title = "At a Glance";
      y = 0;
      collapsed = false;
    })

    (ui.stat {
      id = 1;
      title = "Internet";
      x = 0;
      y = 1;
      w = 3;
      h = 4;
      expr = ''(min(janus_network_probe_up{group=~"wan|internet"}) or vector(0)) * (max(janus_dns_probe_up) or vector(0))'';
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })

    (ui.stat {
      id = 2;
      title = "Latency";
      x = 3;
      y = 1;
      w = 3;
      h = 4;
      unit = "ms";
      expr = smokepingLatency "0.95" internetQuality;
      threshold = ui.thresholds.latencyMs;
      sparkline = true;
    })

    (ui.stat {
      id = 3;
      title = "Loss";
      x = 6;
      y = 1;
      w = 3;
      h = 4;
      unit = "percent";
      expr = smokepingLoss internetQuality;
      threshold = ui.thresholds.packetLossPercent;
      sparkline = true;
    })

    (ui.stat {
      id = 4;
      title = "Down";
      x = 12;
      y = 1;
      w = 3;
      h = 4;
      unit = "bps";
      expr = bps (rx wan);
      threshold = ui.thresholds.neutral;
      fixedColor = "blue";
      sparkline = true;
    })

    (ui.stat {
      id = 5;
      title = "Up";
      x = 15;
      y = 1;
      w = 3;
      h = 4;
      unit = "bps";
      expr = bps (tx wan);
      threshold = ui.thresholds.neutral;
      fixedColor = "orange";
      sparkline = true;
    })

    (ui.stat {
      id = 6;
      title = "Clients";
      x = 18;
      y = 1;
      w = 3;
      h = 4;
      expr = ''sum(kea_dhcp4_addresses_assigned_total{${janus},pool="",subnet_id=~"${subnetIds}"})'';
      threshold = ui.thresholds.neutral;
      sparkline = true;
    })

    (ui.stat {
      id = 8;
      title = "Faults";
      x = 9;
      y = 1;
      w = 3;
      h = 4;
      expr = linkFaultsInRange;
      threshold = ui.thresholds.goodWhenZero;
      sparkline = true;
    })

    (ui.stat {
      id = 7;
      title = "CPU";
      x = 21;
      y = 1;
      w = 3;
      h = 4;
      unit = "percent";
      expr = cpu;
      threshold = ui.thresholds.pressure;
      sparkline = true;
    })

    (ui.timeseries {
      id = 10;
      title = "WAN Throughput";
      x = 0;
      y = 5;
      w = 8;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "A" (bps (rx wan)) "download")
        (ui.target "B" (bps (tx wan)) "upload")
      ];
      overrides = [
        (ui.colorOverride "download" "blue")
        (ui.colorOverride "upload" "orange")
      ];
    })

    (ui.timeseries {
      id = 11;
      title = "Traffic by Network";
      x = 8;
      y = 5;
      w = 8;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = vlanTargets 0 (vlan: bps (total vlan.interface));
      overrides = vlanColours;
    })

    (ui.timeseries {
      id = 12;
      title = "Internet Latency Percentiles";
      x = 16;
      y = 5;
      w = 8;
      h = 8;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "A" (smokepingLatency "0.50" internetQuality) "p50")
        (ui.target "B" (smokepingLatency "0.90" internetQuality) "p90")
        (ui.target "C" (smokepingLatency "0.95" internetQuality) "p95")
        (ui.target "D" (smokepingLatency "0.99" internetQuality) "p99")
      ];
      overrides = [
        (ui.colorOverride "p50" "green")
        (ui.colorOverride "p90" "blue")
        (ui.colorOverride "p95" "orange")
        (ui.colorOverride "p99" "red")
      ];
    })

    (ui.row {
      id = 100;
      title = "Gateway / WAN";
      y = 14;
      panels = gatewayPanels;
    })

    (ui.row {
      id = 200;
      title = "Interfaces / VLANs";
      y = 23;
      panels = interfacePanels;
    })

    (ui.row {
      id = 300;
      title = "DHCP";
      y = 39;
      panels = dhcpPanels;
    })

    (ui.row {
      id = 400;
      title = "DNS";
      y = 55;
      panels = dnsPanels;
    })

    (ui.row {
      id = 500;
      title = "Router System";
      y = 79;
      panels = routerSystemPanels;
    })

    (ui.row {
      id = 510;
      title = "Firewall";
      y = 92;
      panels = firewallPanels;
    })

    (ui.row {
      id = 600;
      title = "Network Devices";
      y = 113;
      panels = devicePanels;
    })
  ];
}

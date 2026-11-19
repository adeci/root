{
  ui,
  network,
  queries,
}:
let
  inherit (queries) router mikrotik;

  # One series per device, named as `name`: the router's reading, then each appliance's.
  device =
    routerReading: applianceReading:
    ''max by (name) (label_replace(${routerReading}, "name", "${network.instance}", "", "") or ${applianceReading})'';
  appliancesUp = ''label_replace(janus_network_probe_up{${router}, group="routeros"}, "name", "$1", "target", "(.+)")'';
  up = device ''up{${router}, job="node"}'' appliancesUp;
  # An alert about an appliance names it, as `name` or `target`; any other is about the router.
  severity = ''label_replace(2 * ALERTS{${router}, alertstate="firing", severity="critical"} or ALERTS{${router}, alertstate="firing", severity="warning"}, "name", "$1", "target", "(.+)")'';

  # Each appliance port on a known cable, named as `port` "nexus ether2".
  onCables =
    query:
    ''label_join(${network.onPorts network.cableNearEnds query}, "port", " ", "name", "interface")'';
  perPort = aggregation: query: "${aggregation} by (port) (${onCables query})";
  # 0 down, 1 slow, 2 at full speed. mikrotik_monitor_rate is in Mb/s; SFP+ ports should link at 10 Gb/s, copper ports at 1 Gb/s. A port down has no rate.
  linkState = onCables (ports: ''
    mikrotik_monitor_status{${mikrotik}, ${ports}} * (1 + (
      mikrotik_monitor_rate{${mikrotik}, ${ports}, interface=~"sfp-sfpplus.+"} >= bool 10000
      or mikrotik_monitor_rate{${mikrotik}, ${ports}, interface=~"ether.+"} >= bool 1000
    ))
    or mikrotik_monitor_status{${mikrotik}, ${ports}}
  '');
in
ui.row {
  title = "Devices";
  collapsed = false;
  panels = [
    (ui.mergedTable {
      title = "Devices";
      description = "The router and the appliances. Restarts counts those in the picked time range.";
      w = 24;
      # The router and each appliance, plus the title and the header.
      h = builtins.length network.appliances + 3;
      sortBy = [
        {
          displayName = "Device";
          desc = false;
        }
      ];
      renamedColumns.name = "Device";
      columns = [
        {
          name = "Up";
          width = 50;
          expr = up;
          threshold = ui.thresholds.goodWhenOne;
          valueMappings = ui.mappings.dot;
        }
        {
          name = "Alerts";
          width = 80;
          # 0, shown blank, keeps the column when none fires.
          expr = ''max by (name) (${severity} and on (name) ${appliancesUp}) or label_replace(max(${severity} unless on (name) ${appliancesUp}), "name", "${network.instance}", "", "") or 0 * ${up}'';
          threshold = ui.thresholds.alertSeverity;
          valueMappings = ui.mappings.alertSeverity;
        }
        {
          name = "CPU";
          expr = device ''100 * (1 - sum(rate(node_cpu_seconds_total{${router}, mode="idle"}[$__rate_interval])) / sum(rate(node_cpu_seconds_total{${router}}[$__rate_interval])))'' "mikrotik_system_cpu_load{${mikrotik}}";
          unit = "percent";
          decimals = 0;
          bar = ui.colours.cpu;
        }
        {
          name = "Memory";
          expr = device "100 * (1 - node_memory_MemAvailable_bytes{${router}} / node_memory_MemTotal_bytes{${router}})" "100 * (1 - mikrotik_system_free_memory{${mikrotik}} / mikrotik_system_total_memory{${mikrotik}})";
          unit = "percent";
          decimals = 0;
          bar = ui.colours.memory;
        }
        {
          name = "Disk";
          expr = device "100 * disk:used:ratio{${router}}" "100 * (1 - mikrotik_system_free_hdd_space{${mikrotik}} / mikrotik_system_total_hdd_space{${mikrotik}})";
          unit = "percent";
          decimals = 0;
          bar = ui.colours.disk;
        }
        {
          name = "Temp";
          width = 80;
          expr = device ''node_hwmon_temp_celsius{${router}, chip="platform_coretemp_0"}'' "janus_routeros_temperature_celsius{${router}}";
          unit = "celsius";
          decimals = 0;
        }
        {
          name = "Uptime";
          width = 110;
          expr = device ''time() - node_boot_time_seconds{${router}, job="node"}'' "mikrotik_system_uptime{${mikrotik}}";
          unit = "s";
        }
        {
          name = "Restarts";
          width = 90;
          # An appliance's uptime starts a new series when its RouterOS version changes, so its restarts are counted on the highest.
          expr = device ''changes(node_boot_time_seconds{${router}, job="node"}[$__range])'' "resets((max by (name) (mikrotik_system_uptime{${mikrotik}}))[$__range:1m])";
          valueMappings = ui.mappings.blankZero;
        }
      ];
    })
    (ui.mergedTable {
      title = "Links";
      description = "Each known cable at the appliance port it is written on. Errors and link downs count those in the picked time range. Traffic is the busiest moment in that range, beside its course.";
      w = 15;
      # A grid unit per cable, plus the title and the header.
      h = builtins.length (builtins.attrNames network.cableEnds) + 2;
      joinBy = "port";
      sortBy = [
        {
          displayName = "Port";
          desc = false;
        }
      ];
      renamedColumns = {
        port = "Port";
        to = "To";
      };
      firstColumns = [
        "port"
        "to"
      ];
      labelColumns.To.valueMappings = queries.showAs network.cableEnds;
      columns = [
        {
          name = "Link";
          width = 90;
          expr = ''max by (port, to) (label_join(${linkState}, "to", "", "port"))'';
          threshold = ui.thresholds.linkState;
          colours = ui.mappings.linkTrouble;
        }
        {
          name = "Speed";
          width = 90;
          expr = "1000000 * ${perPort "max" (ports: "mikrotik_monitor_rate{${mikrotik}, ${ports}}")}";
          unit = "bps";
        }
        {
          name = "PoE";
          width = 70;
          expr = perPort "max" (ports: ''mikrotik_poe_wattage{${router}, job="mikrotik-poe", ${ports}}'');
          unit = "watt";
        }
        {
          name = "Link downs";
          width = 90;
          expr = perPort "sum" (
            ports: "increase(mikrotik_interface_link_downs{${mikrotik}, ${ports}}[$__range])"
          );
          decimals = 0;
          valueMappings = ui.mappings.blankZero;
        }
        {
          name = "Traffic";
          expr = "8 * ${
            perPort "sum" (
              ports:
              "rate(mikrotik_interface_rx_byte{${mikrotik}, ${ports}}[$__rate_interval]) + rate(mikrotik_interface_tx_byte{${mikrotik}, ${ports}}[$__rate_interval])"
            )
          }";
          unit = "bps";
          sparkline = ui.colours.traffic;
        }
      ];
    })
    (ui.stateTimeline {
      title = "Speed";
      w = 9;
      h = builtins.length (builtins.attrNames network.cableEnds) + 2;
      targets = [ (ui.target "max by (port) (${linkState})" "{{port}}") ];
      threshold = ui.thresholds.linkState;
      valueMappings = ui.mappings.linkState;
    })
  ];
}

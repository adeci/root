let
  ui = import ./lib.nix;
  queries = import ./queries.nix;
  disk = import ../disks.nix;

  host = ''instance="$host"'';
  cores = ''scalar(count(node_cpu_seconds_total{${host}, mode="idle"}))'';
  disks = ''device!~"loop.*|ram.*|zram.*"'';
  # Loopback is lo on Linux, lo0 on macOS.
  interfaces = ''device!~"lo|lo0"'';
  pressure =
    resource: kind: "rate(node_pressure_${resource}_${kind}_seconds_total{${host}}[$__rate_interval])";
in
ui.dashboard {
  uid = "host";
  title = "Host";
  variables = [
    (ui.labelVariable {
      name = "host";
      label = "Host";
      query = ''label_values(up{job="node"}, instance)'';
    })
  ];
  panels = [
    (ui.timeseries {
      title = "CPU busy";
      w = 12;
      h = 8;
      unit = "percent";
      targets = [
        (ui.target ''100 * sum by (mode) (rate(node_cpu_seconds_total{${host}, mode!="idle"}[$__rate_interval])) / ${cores}'' "{{mode}}")
      ];
    })
    (ui.timeseries {
      title = "Load per core";
      w = 12;
      h = 8;
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "node_load1{${host}} / ${cores}" "1m")
        (ui.target "node_load5{${host}} / ${cores}" "5m")
        (ui.target "node_load15{${host}} / ${cores}" "15m")
      ];
    })
    (ui.timeseries {
      title = "Memory used";
      w = 12;
      h = 8;
      unit = "percent";
      targets = [ (ui.target (queries.memoryUsed host) "used") ];
    })
    (ui.timeseries {
      title = "Swap used";
      w = 12;
      h = 8;
      unit = "bytes";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "node_memory_SwapTotal_bytes{${host}} - node_memory_SwapFree_bytes{${host}} or node_memory_swap_used_bytes{${host}}" "used")
      ];
    })
    (ui.timeseries {
      title = "Disk space used";
      w = 12;
      h = 8;
      unit = "percent";
      targets = [
        (ui.target "100 * (1 - node_filesystem_avail_bytes{${host}, ${disk}} / node_filesystem_size_bytes{${host}, ${disk}})" "{{mountpoint}}")
      ];
    })
    (ui.timeseries {
      title = "Disk I/O";
      w = 12;
      h = 8;
      unit = "Bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "rate(node_disk_read_bytes_total{${host}, ${disks}}[$__rate_interval])" "{{device}} read")
        (ui.target "rate(node_disk_written_bytes_total{${host}, ${disks}}[$__rate_interval])" "{{device}} written")
      ];
    })
    (ui.timeseries {
      title = "Network";
      w = 12;
      h = 8;
      unit = "bps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target "8 * rate(node_network_receive_bytes_total{${host}, ${interfaces}}[$__rate_interval])" "{{device}} in")
        (ui.target "8 * rate(node_network_transmit_bytes_total{${host}, ${interfaces}}[$__rate_interval])" "{{device}} out")
      ];
    })
    (ui.timeseries {
      title = "Pressure (Linux)";
      w = 12;
      h = 8;
      unit = "percentunit";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target (pressure "cpu" "waiting") "cpu some")
        (ui.target (pressure "memory" "waiting") "memory some")
        (ui.target (pressure "memory" "stalled") "memory full")
        (ui.target (pressure "io" "waiting") "io some")
        (ui.target (pressure "io" "stalled") "io full")
      ];
    })
  ];
}

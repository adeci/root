let
  ui = import ./lib.nix;

  firingCount = matcher: ''count(ALERTS{alertstate="firing", ${matcher}}) or vector(0)'';

  rootDiskUsed = ''100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})'';
  memoryUsed = "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)";
  loadPerCore = ''node_load15 / on (instance) count by (instance) (node_cpu_seconds_total{mode="idle"})'';
  cpuBusy = ''100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval])))'';
  networkTraffic = ''sum by (instance) (rate(node_network_receive_bytes_total{device!="lo"}[$__rate_interval]) + rate(node_network_transmit_bytes_total{device!="lo"}[$__rate_interval]))'';
in
ui.dashboard {
  uid = "fleet";
  title = "Fleet";
  panels = [
    (ui.stat {
      title = "Machines down";
      w = 6;
      h = 4;
      expr = firingCount ''alertname="HostDown"'';
    })
    (ui.stat {
      title = "Critical alerts";
      w = 6;
      h = 4;
      expr = firingCount ''severity="critical"'';
    })
    (ui.stat {
      title = "Warnings";
      w = 6;
      h = 4;
      expr = firingCount ''severity="warning"'';
      threshold = ui.thresholds.cautionWhenNonZero;
    })
    (ui.stat {
      title = "Machines reporting";
      w = 6;
      h = 4;
      expr = ''count(present_over_time(up{job="integrations/unix"}[5m]))'';
      threshold = ui.thresholds.neutral;
    })
    (ui.table {
      title = "Firing alerts";
      w = 24;
      h = 8;
      targets = [ (ui.tableTarget ''ALERTS{alertstate="firing"}'') ];
      hiddenColumns = [
        "Time"
        "Value"
        "__name__"
        "alertstate"
      ];
    })
    (ui.barGauge {
      title = "Root disk used";
      w = 8;
      h = 9;
      unit = "percent";
      targets = [ (ui.target rootDiskUsed "{{instance}}") ];
    })
    (ui.barGauge {
      title = "Memory used";
      w = 8;
      h = 9;
      unit = "percent";
      targets = [ (ui.target memoryUsed "{{instance}}") ];
    })
    (ui.barGauge {
      title = "Load per core";
      w = 8;
      h = 9;
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target loadPerCore "{{instance}}") ];
    })
    (ui.timeseries {
      title = "CPU busy";
      w = 12;
      h = 8;
      unit = "percent";
      targets = [ (ui.target cpuBusy "{{instance}}") ];
    })
    (ui.timeseries {
      title = "Network traffic";
      w = 12;
      h = 8;
      unit = "Bps";
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target networkTraffic "{{instance}}") ];
    })
    (ui.logs {
      title = "Errors in the journal";
      w = 24;
      h = 10;
      expr = ''{level=~"emerg|alert|crit|err"}'';
    })
  ];
}

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
      id = 1;
      title = "Machines down";
      x = 0;
      y = 0;
      w = 6;
      h = 4;
      expr = firingCount ''alertname="HostDown"'';
    })
    (ui.stat {
      id = 2;
      title = "Critical alerts";
      x = 6;
      y = 0;
      w = 6;
      h = 4;
      expr = firingCount ''severity="critical"'';
    })
    (ui.stat {
      id = 3;
      title = "Warnings";
      x = 12;
      y = 0;
      w = 6;
      h = 4;
      expr = firingCount ''severity="warning"'';
      threshold = ui.thresholds.cautionWhenNonZero;
    })
    (ui.stat {
      id = 4;
      title = "Machines reporting";
      x = 18;
      y = 0;
      w = 6;
      h = 4;
      expr = ''count(present_over_time(up{job="integrations/unix"}[5m]))'';
      threshold = ui.thresholds.neutral;
    })
    (ui.table {
      id = 5;
      title = "Firing alerts";
      x = 0;
      y = 4;
      w = 24;
      h = 8;
      targets = [ (ui.tableTarget "A" ''ALERTS{alertstate="firing"}'') ];
      hiddenColumns = [
        "Time"
        "Value"
        "__name__"
        "alertstate"
      ];
    })
    (ui.barGauge {
      id = 6;
      title = "Root disk used";
      x = 0;
      y = 12;
      w = 8;
      h = 9;
      unit = "percent";
      targets = [ (ui.target "A" rootDiskUsed "{{instance}}") ];
    })
    (ui.barGauge {
      id = 7;
      title = "Memory used";
      x = 8;
      y = 12;
      w = 8;
      h = 9;
      unit = "percent";
      targets = [ (ui.target "A" memoryUsed "{{instance}}") ];
    })
    (ui.barGauge {
      id = 8;
      title = "Load per core";
      x = 16;
      y = 12;
      w = 8;
      h = 9;
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target "A" loadPerCore "{{instance}}") ];
    })
    (ui.timeseries {
      id = 9;
      title = "CPU busy";
      x = 0;
      y = 21;
      w = 12;
      h = 8;
      unit = "percent";
      targets = [ (ui.target "A" cpuBusy "{{instance}}") ];
    })
    (ui.timeseries {
      id = 10;
      title = "Network traffic";
      x = 12;
      y = 21;
      w = 12;
      h = 8;
      unit = "Bps";
      threshold = ui.thresholds.neutral;
      targets = [ (ui.target "A" networkTraffic "{{instance}}") ];
    })
    (ui.logs {
      id = 11;
      title = "Errors in the journal";
      x = 0;
      y = 29;
      w = 24;
      h = 10;
      expr = ''{level=~"emerg|alert|crit|err"}'';
    })
  ];
}

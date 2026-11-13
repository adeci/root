{ ui, queries, ... }:
let
  inherit (queries) router;

  memory = "100 * (1 - node_memory_MemAvailable_bytes{${router}} / node_memory_MemTotal_bytes{${router}})";
  conntrack = "100 * node_nf_conntrack_entries{${router}} / node_nf_conntrack_entries_limit{${router}}";
  loadPerCore = ''node_load1{${router}} / scalar(count(count by(cpu) (node_cpu_seconds_total{${router},mode="idle"})))'';
  rootDisk = ''100 * (1 - node_filesystem_avail_bytes{${router},mountpoint="/"} / node_filesystem_size_bytes{${router},mountpoint="/"})'';
  diskDevices = "loop.*|ram.*|zram.*";
  diskBusy = ''100 * rate(node_disk_io_time_seconds_total{${router},device!~"${diskDevices}"}[$__rate_interval])'';
  diskWrites = ''sum(rate(node_disk_written_bytes_total{${router},device!~"${diskDevices}"}[$__rate_interval]))'';
  ioWaiting = "100 * rate(node_pressure_io_waiting_seconds_total{${router}}[$__rate_interval])";

  active =
    unit: ''max(node_systemd_unit_state{${router},name="${unit}",state="active"}) or vector(0)'';
  failedUnits = ''sum(node_systemd_unit_state{${router},state="failed"} == 1) or vector(0)'';
  degraded = "(1 - max(node_systemd_system_running{${router}})) or vector(1)";
  textfilesFresh =
    files:
    ''(max(time() - node_textfile_mtime_seconds{${router},file=~"${files}"}) < bool 300) or vector(0)'';
  firewallCountersFresh = textfilesFresh ".*/janus-firewall-counters.prom";
in
ui.row {
  title = "Router System";
  panels = [
    (ui.stat {
      title = "DHCP";
      w = 3;
      h = 4;
      expr = active "kea-dhcp4-server.service";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      title = "DNS";
      w = 3;
      h = 4;
      expr = active "unbound.service";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      title = "Firewall";
      w = 3;
      h = 4;
      expr = "(${active "nftables.service"}) * (${firewallCountersFresh})";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      title = "Tailscale";
      w = 3;
      h = 4;
      expr = active "tailscaled.service";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      title = "Telemetry";
      w = 3;
      h = 4;
      expr = "(min(up{${router}}) or vector(0)) * (${textfilesFresh ".*"})";
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.stat {
      title = "Problems";
      w = 3;
      h = 4;
      expr = "(${failedUnits}) + (${degraded}) + (1 - (${firewallCountersFresh}))";
      threshold = ui.thresholds.goodWhenZero;
    })
    (ui.stat {
      title = "CPU Temp";
      w = 3;
      h = 4;
      unit = "celsius";
      expr = ''max(node_hwmon_temp_celsius{${router},chip="platform_coretemp_0"})'';
      threshold = ui.thresholds.temperatureC;
    })
    (ui.stat {
      title = "NVMe Temp";
      w = 3;
      h = 4;
      unit = "celsius";
      expr = ''max(node_hwmon_temp_celsius{${router},chip="nvme_nvme0"})'';
      threshold = ui.thresholds.temperatureC;
    })

    (ui.barGauge {
      title = "Router Resources";
      w = 8;
      h = 7;
      unit = "percent";
      targets = [
        (ui.target queries.cpu "cpu")
        (ui.target memory "memory")
        (ui.target conntrack "firewall states")
        (ui.target rootDisk "root disk")
      ];
      overrides = [
        (ui.colorOverride "cpu" "blue")
        (ui.colorOverride "memory" "yellow")
        (ui.colorOverride "firewall states" "green")
        (ui.colorOverride "root disk" "orange")
      ];
    })
    (ui.stat {
      title = "Load Per Core";
      w = 4;
      h = 7;
      expr = loadPerCore;
      threshold = ui.thresholds.pressure;
      sparkline = true;
    })
    (ui.stat {
      title = "Disk Busy";
      w = 4;
      h = 7;
      unit = "percent";
      expr = "max(${diskBusy}) or vector(0)";
      threshold = ui.thresholds.ioPressure;
      sparkline = true;
    })
    (ui.stat {
      title = "IO Wait";
      w = 4;
      h = 7;
      unit = "percent";
      expr = ioWaiting;
      threshold = ui.thresholds.ioPressure;
      sparkline = true;
    })
    (ui.stat {
      title = "Disk Writes";
      w = 4;
      h = 7;
      unit = "Bps";
      expr = diskWrites;
      threshold = ui.thresholds.neutral;
      fixedColor = "blue";
      sparkline = true;
    })
  ];
}

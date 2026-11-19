# The machines the agents run on, each as { os, kind }.
machines:
let
  ui = import ./lib.nix;

  # Every panel matches the three pickers, but for the public names, which belong to no machine they list.
  selected = ''os=~"$os", kind=~"$kind", instance=~"$host"'';
  # The jobs keep out the Alloy-era series still stored under the same names.
  node = ''job="node", ${selected}'';
  linux = ''${node}, os="linux"'';
  macos = ''${node}, os="macos"'';
  servers = ''${node}, kind="server"'';
  laptops = ''${node}, kind="laptop"'';
  # Linux drives report through smartctl_exporter; a Mac's internal SSD through node_exporter's text files.
  smart = ''job=~"smartctl|node", ${selected}'';
  machine = "instance, os, kind";

  # A colour per machine, unique within its kind: the machines, sorted by name, take the palette in turn.
  palette = [
    "#F2495C"
    "#FF9830"
    "#FADE2A"
    "#73BF69"
    "#3CC6D0"
    "#5794F2"
    "#B877D9"
    "#FF85C8"
    "#C8C8C8"
  ];
  machinesByKind = builtins.groupBy (name: machines.${name}.kind) (builtins.attrNames machines);
  machineColours = builtins.concatLists (
    builtins.attrValues (
      builtins.mapAttrs (
        _: names:
        let
          sorted = builtins.sort builtins.lessThan names;
          count = builtins.length palette;
        in
        builtins.genList (
          index:
          ui.colorOverrideMatching "^${builtins.elemAt sorted index}( |$)" (
            builtins.elemAt palette (index - index / count * count)
          )
        ) (builtins.length sorted)
      ) machinesByKind
    )
  );
  linuxMachineCount = builtins.length (
    builtins.filter (name: machines.${name}.os == "linux") (builtins.attrNames machines)
  );

  # A Linux machine's reading from its last boot, or the shutdown before it.
  bootReading = metric: "max by (instance) (${metric}{${linux}})";
  # The units slowest to start or to stop, five a machine, the slowest in the fleet first.
  slowestUnits =
    { title, metric }:
    ui.mergedTable {
      inherit title;
      w = 12;
      h = 12;
      sortBy = [
        {
          displayName = "Took";
          desc = true;
        }
      ];
      renamedColumns = {
        instance = "Host";
        unit = "Unit";
      };
      columns = [
        {
          name = "Took";
          expr = "max by (instance, unit) (${metric}{${linux}})";
          unit = "s";
        }
      ];
    };

  lines = panel: ui.timeseries (panel // { overrides = machineColours ++ panel.overrides or [ ]; });
  # One copy of the graph per kind, side by side, so no two machines in a copy share a colour.
  linesPerKind =
    panel:
    lines (
      panel
      // {
        w = 24;
        h = 8;
        repeat = "kind";
      }
    );
  # Half the page wide, both Macs in one graph: they are a server and a laptop, whose colours differ.
  macLines =
    panel:
    lines (
      panel
      // {
        w = 12;
        h = 8;
      }
    );

  # 1 up, 0 down.
  up = kind: ''max by (${machine}) (up{${node}, kind="${kind}"})'';
  # A public name's reading from the last request to it.
  publicName = metric: ''max by (name) (${metric}{job="probe"})'';
  # A backup's reading: from its repository's newest snapshot, or from a series named after the backup.
  backup = expr: "max by (instance, backup) (${expr})";
  snapshotAge = "(time() - restic_snapshot_timestamp_seconds{${node}})";
  # How many of its two ages a backup has passed: 36 and 72 hours on a server, 3 and 7 days by the clock on a laptop, whose alerts count only its time on.
  backupStaleness =
    let
      passed =
        matchers: old: tooOld:
        "(time() - restic_snapshot_timestamp_seconds{${matchers}} > bool ${old}) + (time() - restic_snapshot_timestamp_seconds{${matchers}} > bool ${tooOld})";
    in
    "(${passed servers "36 * 3600" "72 * 3600"}) or (${passed laptops "3 * 86400" "7 * 86400"})";
  # Idle time against all CPU time, not against the step: a machine up for only part of a step would read near 100 %.
  cpuBusy =
    matchers:
    ''100 * (1 - sum by (${machine}) (rate(node_cpu_seconds_total{mode="idle", ${matchers}}[$__rate_interval])) / sum by (${machine}) (rate(node_cpu_seconds_total{${matchers}}[$__rate_interval])))'';
  # Linux reports what is available; on a Mac, Activity Monitor's "Memory Used" is app memory, wired and compressed.
  memoryUsed = matchers: ''
    100 * max by (${machine}) (
      1 - node_memory_MemAvailable_bytes{${matchers}} / node_memory_MemTotal_bytes{${matchers}}
      or (node_memory_internal_bytes{${matchers}} - node_memory_purgeable_bytes{${matchers}} + node_memory_wired_bytes{${matchers}} + node_memory_compressed_bytes{${matchers}}) / node_memory_total_bytes{${matchers}}
    )
  '';
  # The average over all cores and each step: a lower idle floor or a lost boost both show.
  cpuClock = "avg by (instance) (avg_over_time(node_cpu_scaling_frequency_hertz{${linux}}[$__rate_interval]))";
  waiting =
    resource: "rate(node_pressure_${resource}_waiting_seconds_total{${linux}}[$__rate_interval])";
  pressure = resource: "100 * max by (instance) (${waiting resource})";
  # The worst of the three; each carries its resource as a label, or `or` would keep only the first.
  worstPressure =
    let
      named = resource: ''label_replace(${waiting resource}, "resource", "${resource}", "", "")'';
    in
    "100 * max by (instance) (${named "cpu"} or ${named "memory"} or ${named "io"})";
  macMemoryPressure = "max by (instance) (macos_memory_pressure_level{${macos}})";
  cpuChips = ''chip_name=~"coretemp|k10temp|cpu_thermal"'';
  # Averaged per step: some sensors swing by ten degrees from one scrape to the next. A Mac reports its cores' average, from its health job.
  cpuTemperature =
    matchers:
    "max by (${machine}) (avg_over_time(node_hwmon_temp_celsius{${matchers}}[$__rate_interval]) * on (instance, chip) group_left (chip_name) node_hwmon_chip_names{${matchers}, ${cpuChips}}) or max by (${machine}) (macos_cpu_temperature_celsius{${matchers}})";
  # Whole disks: NVMe namespaces, SCSI, SATA and virtio disks and SD cards, not partitions, device mapper or optical drives.
  physicalDisks = ''device=~"nvme[0-9]+n[0-9]+|[hsv]d[a-z]+|xvd[a-z]+|mmcblk[0-9]+"'';
  # Received plus sent. Loopback is lo on Linux, lo0 on macOS; the busiest interface stands for the machine, so bridges don't count twice.
  networkTraffic =
    matchers:
    let
      interfaces = ''device!~"lo|lo0", ${matchers}'';
    in
    "8 * max by (instance) (rate(node_network_receive_bytes_total{${interfaces}}[$__rate_interval]) + rate(node_network_transmit_bytes_total{${interfaces}}[$__rate_interval]))";
  # Read plus written, per disk.
  diskIo =
    matchers:
    "rate(node_disk_read_bytes_total{${matchers}}[$__rate_interval]) + rate(node_disk_written_bytes_total{${matchers}}[$__rate_interval])";
  # vm_stat's page-ins plus page-outs, which node_exporter names swapped in and out.
  paging = "max by (instance) (rate(node_memory_swapped_in_bytes_total{${macos}}[$__rate_interval]) + rate(node_memory_swapped_out_bytes_total{${macos}}[$__rate_interval]))";
  # A laptop battery's reading, not a peripheral's (scope "Device") such as a headset's; a Mac calls its battery's type InternalBattery.
  laptopBattery =
    reading:
    ''max by (${machine}) (${reading} * on (instance, power_supply) group_left () node_power_supply_info{${laptops}, type=~"Battery|InternalBattery", scope!="Device"})'';
  # A Mac reports its charge against a maximum, and its health through its health job.
  batteryCharge = laptopBattery "(node_power_supply_capacity{${laptops}} or 100 * node_power_supply_current_capacity{${laptops}} / node_power_supply_max_capacity{${laptops}})";
  batteryHealth = "clamp_max(100 * (${laptopBattery "(node_power_supply_energy_full{${laptops}} / node_power_supply_energy_full_design{${laptops}} or node_power_supply_charge_full{${laptops}} / node_power_supply_charge_full_design{${laptops}})"} or max by (${machine}) (macos_battery_health_ratio{${laptops}})), 100)";
  laptopsOnline = "up{${laptops}} == 1";
  # dbus-broker logs "Ignoring duplicate name" at error level whenever a user manager starts; it is not a failure.
  journalErrors = ''{instance=~"$host", level=~"emerg|alert|crit|err"} != "Ignoring duplicate name"'';
  # Each line says where it's from.
  recentErrors = ''${journalErrors} | line_format "{{.instance}} {{.service_name}}: {{__line__}}"'';
  # A message is its first line with whole numbers as N, so its repeats group together.
  errorMessages = ''${journalErrors} | label_format service=`{{ regexReplaceAll "[0-9]+" .service_name "N" }}`, message=`{{ regexReplaceAll "\\b[0-9]+\\b" (regexReplaceAll "(?s)\n.*" __line__ "") "N" | trunc 160 }}`'';
  messageCount =
    range: "sum by (instance, service, message) (count_over_time(${errorMessages} ${range}))";
  newMessages = "${messageCount "[24h]"} unless ${messageCount "[24h] offset 24h"}";

  machineTable =
    table:
    ui.mergedTable (
      table
      // {
        sortBy = [
          {
            displayName = "Host";
            desc = false;
          }
        ];
        renamedColumns.instance = "Host";
        hiddenColumns = [
          "os"
          "kind"
        ];
      }
    );
  usageColumns =
    kind:
    let
      matchers = ''${node}, kind="${kind}"'';
    in
    [
      {
        name = "Memory";
        expr = memoryUsed matchers;
        unit = "percent";
        decimals = 0;
        bar = ui.colours.memory;
      }
      {
        name = "Disk";
        expr = ''100 * max by (${machine}) (disk:used:ratio{${selected}, kind="${kind}"})'';
        unit = "percent";
        decimals = 0;
        bar = ui.colours.disk;
      }
      {
        name = "Temp";
        width = 80;
        expr = cpuTemperature matchers;
        unit = "celsius";
        decimals = 0;
      }
    ];

  # A drive's reading, with its model.
  drive =
    expr:
    "max by (instance, device, model_name) ((${expr}) * on (instance, device) group_left (model_name) smartctl_device{${smart}})";
  # The bad sectors a SATA drive counts, or an NVMe drive's media errors.
  driveErrors =
    ''sum by (instance, device) (smartctl_device_attribute{${smart}, attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|Reported_Uncorrect", attribute_value_type="raw"})''
    + " or max by (instance, device) (smartctl_device_media_errors{${smart}})";

  # When the newest nixpkgs any machine runs, picked or not, was committed.
  newestNixpkgsTime = ''scalar(max(system_nixpkgs_timestamp_seconds{job="node"}))'';
  # Machines behind it, or whose kernel waits for a reboot: the only ones Updates lists.
  outdated = "(${newestNixpkgsTime} - max by (instance) (system_nixpkgs_timestamp_seconds{${node}}) > 0) or max by (instance) (reboot_required{${node}}) == 1";
  # An outdated machine's reading, with the nixpkgs revision it runs.
  update =
    expr:
    "max by (instance, revision_short) ((${expr}) * on (instance) group_left (revision_short) system_nixpkgs_info{${node}}) and on (instance) (${outdated})";
in
ui.dashboard {
  uid = "fleet";
  title = "Fleet";
  # os and kind match everything when All; the host picker's All is the hosts they leave, which also narrows the journal, whose lines have no os or kind.
  variables = [
    (ui.labelVariable {
      name = "os";
      label = "OS";
      query = ''label_values(up{job="node"}, os)'';
      allValue = ".*";
    })
    (ui.labelVariable {
      name = "kind";
      label = "Kind";
      query = ''label_values(up{job="node"}, kind)'';
      allValue = ".*";
      # Servers first.
      sort = 2;
    })
    (ui.labelVariable {
      name = "host";
      label = "Host";
      query = ''label_values(up{job="node", os=~"$os", kind=~"$kind"}, instance)'';
    })
  ];
  panels = [
    (ui.row {
      title = "Now";
      collapsed = false;
      panels = [
        (ui.alerts {
          w = 14;
          h = 5;
          matchers = selected;
        })
        (ui.mergedTable {
          title = "Updates";
          w = 10;
          h = 5;
          noDataText = "No machine is behind or needs a reboot";
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns = {
            instance = "Host";
            revision_short = "Nixpkgs";
          };
          firstColumns = [
            "instance"
            "revision_short"
          ];
          labelColumns = {
            Host.width = 80;
            Nixpkgs.width = 76;
          };
          columns = [
            {
              name = "Behind";
              width = 64;
              expr = update "${newestNixpkgsTime} - system_nixpkgs_timestamp_seconds{${node}}";
              unit = "s";
              valueMappings = ui.mappings.blankZero;
            }
            {
              name = "Switched";
              expr = update "1000 * system_switch_timestamp_seconds{${node}}";
              unit = "dateTimeFromNow";
            }
            {
              name = "Reboot";
              width = 66;
              # A Mac has no kernel to wait for; it counts as 0.
              expr = update "reboot_required{${node}} or 0 * system_nixpkgs_timestamp_seconds{${node}}";
              threshold = ui.thresholds.cautionWhenNonZero;
              valueMappings = ui.mappings.rebootNeeded;
            }
          ];
        })
        (machineTable {
          title = "Servers";
          description = "Peak is the highest CPU use in the picked time range, beside its course over that range.";
          w = 24;
          # A grid unit per server, plus the title and the header.
          h = builtins.length (machinesByKind.server or [ ]) + 2;
          firstColumns = [ "instance" ];
          joinBy = "instance";
          columns = [
            {
              name = "Up";
              width = 50;
              expr = up "server";
              threshold = ui.thresholds.goodWhenOne;
              valueMappings = ui.mappings.dot;
            }
            {
              name = "Alerts";
              width = 80;
              # The worst alert on each server, matched on instance alone as some alerts carry no os or kind; 0, shown blank, keeps the column when none fires.
              expr = ''max by (instance) (2 * ALERTS{alertstate="firing", severity="critical"} or ALERTS{alertstate="firing", severity="warning"}) * on (instance) group_left (os, kind) group by (${machine}) (up{${servers}}) or 0 * ${up "server"}'';
              threshold = ui.thresholds.alertSeverity;
              valueMappings = ui.mappings.alertSeverity;
            }
            {
              name = "CPU";
              expr = cpuBusy servers;
              unit = "percent";
              decimals = 0;
              bar = ui.colours.cpu;
            }
            {
              name = "Peak";
              expr = cpuBusy servers;
              unit = "percent";
              decimals = 0;
              sparkline = ui.colours.cpu;
            }
          ]
          ++ usageColumns "server"
          ++ [
            {
              name = "Uptime";
              width = 110;
              expr = "max by (${machine}) (time() - node_boot_time_seconds{${servers}})";
              unit = "s";
            }
          ];
        })
        (ui.mergedTable {
          title = "New errors";
          description = "Error messages from the last 24 hours that did not occur in the 24 hours before.";
          w = 24;
          h = 5;
          datasource = ui.loki;
          noDataText = "No error message is new since yesterday";
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns = {
            instance = "Host";
            service = "Service";
            message = "Message";
          };
          firstColumns = [
            "instance"
            "service"
            "message"
          ];
          labelColumns = {
            Host.width = 110;
            Service.width = 240;
          };
          columns = [
            {
              name = "Count";
              width = 80;
              expr = newMessages;
            }
          ];
        })
        (machineTable {
          title = "Laptops";
          description = "Laptops that are online. Health is the battery's full capacity against its design capacity.";
          w = 19;
          h = 6;
          noDataText = "No laptop is online";
          columns = [
            {
              name = "CPU";
              # A rate goes on for a few minutes after a laptop goes away; the gauges do not.
              expr = "(${cpuBusy laptops}) and on (instance) (${laptopsOnline})";
              unit = "percent";
              decimals = 0;
              bar = ui.colours.cpu;
            }
          ]
          ++ usageColumns "laptop"
          ++ [
            {
              name = "Battery";
              expr = batteryCharge;
              unit = "percent";
              decimals = 0;
              bar = ui.colours.battery;
            }
            {
              name = "Health";
              width = 80;
              expr = batteryHealth;
              unit = "percent";
              decimals = 0;
            }
          ];
        })
        (ui.mergedTable {
          title = "Offline";
          description = "Laptops that are not reporting, and for how long.";
          w = 5;
          h = 6;
          noDataText = "No laptop is offline";
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns.instance = "Host";
          columns = [
            {
              name = "Offline";
              expr = "max by (instance) (up{${laptops}}) == 0";
              # Only lists them: For finds nothing for a laptop not seen in 30 days.
              hidden = true;
            }
            {
              name = "For";
              expr = "time() - max by (instance) (max_over_time(timestamp(${laptopsOnline})[30d:1m])) unless on (instance) (${laptopsOnline})";
              unit = "s";
              decimals = 0;
            }
          ];
        })
      ];
    })

    (ui.row {
      title = "Public names";
      collapsed = false;
      panels = [
        (ui.mergedTable {
          title = "Public names";
          description = "Each name as the last request to it found it, one a minute. Peak is the slowest response in the picked time range, beside its course over that range. Tunnel counts the connections to Cloudflare its machine holds: four when healthy.";
          w = 15;
          # Eight names today, plus the title and the header.
          h = 10;
          joinBy = "name";
          sortBy = [
            {
              displayName = "Name";
              desc = false;
            }
          ];
          renamedColumns = {
            name = "Name";
            instance = "Served by";
          };
          firstColumns = [
            "name"
            "instance"
          ];
          columns = [
            {
              name = "Up";
              width = 50;
              expr = ''max by (name, instance) (probe_success{job="probe"})'';
              threshold = ui.thresholds.goodWhenOne;
              valueMappings = ui.mappings.dot;
            }
            {
              name = "Status";
              width = 70;
              expr = publicName "probe_http_status_code";
              threshold = ui.thresholds.httpStatus;
              valueMappings = ui.mappings.noAnswer;
            }
            {
              name = "Response";
              width = 90;
              expr = publicName "probe_duration_seconds";
              unit = "s";
            }
            {
              name = "Peak";
              expr = publicName "probe_duration_seconds";
              unit = "s";
              sparkline = ui.colours.response;
            }
            {
              name = "Tunnel";
              width = 70;
              # Only a name whose machine has a tunnel gets a value.
              expr = ''max by (name) (0 * probe_success{job="probe"} + on (instance) group_left () max by (instance) (cloudflared_tunnel_ha_connections))'';
              threshold = ui.thresholds.tunnelConnections;
            }
            {
              name = "Certificate";
              width = 100;
              expr = ''max by (name) (probe_ssl_earliest_cert_expiry{job="probe"} - time())'';
              unit = "s";
              decimals = 0;
              threshold = ui.thresholds.certificateLifeSeconds;
            }
          ];
        })
        (ui.stateTimeline {
          title = "Answering";
          w = 9;
          h = 10;
          targets = [ (ui.target (publicName "probe_success") "{{name}}") ];
          threshold = ui.thresholds.goodWhenOne;
          valueMappings = ui.mappings.upDown;
        })
      ];
    })

    (ui.row {
      title = "Backups";
      collapsed = false;
      panels = [
        (ui.mergedTable {
          title = "Backups";
          description = "Each repository's newest snapshot, as its machine found it when it last asked, which it does every hour. A server's backup is old after 36 hours and too old after 72, a laptop's after 3 and 7 days.";
          w = 15;
          # Eight backups, the laptops' among them, plus the title and the header; a table this short needs one more for its last row.
          h = 11;
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns = {
            instance = "Host";
            backup = "Backup";
          };
          firstColumns = [
            "instance"
            "backup"
          ];
          columns = [
            # Grafana's shortest durations, as 03s, 52m or 22h, so the table fits.
            {
              name = "Age";
              expr = backup snapshotAge;
              unit = "clocks";
              decimals = 0;
            }
            {
              name = "Fresh";
              expr = backup backupStaleness;
              colours = ui.mappings.backupAge;
            }
            {
              name = "Size";
              expr = backup "restic_snapshot_size_bytes{${node}}";
              unit = "bytes";
            }
            {
              name = "Added";
              expr = backup "restic_snapshot_added_bytes{${node}}";
              unit = "bytes";
            }
            {
              name = "Took";
              expr = backup "restic_snapshot_duration_seconds{${node}}";
              unit = "clocks";
              decimals = 0;
            }
            {
              name = "Last run";
              # 1 unless the backup's unit is in the failed state.
              expr = "1 - ${backup ''label_replace(node_systemd_unit_state{${node}, name=~"restic-backups-.+[.]service", state="failed"}, "backup", "$1", "name", "restic-backups-(.+)[.]service")''}";
              threshold = ui.thresholds.goodWhenOne;
              valueMappings = ui.mappings.passed;
            }
            {
              name = "Asked";
              expr = backup ''label_replace(time() - node_textfile_mtime_seconds{${node}, file=~".*/restic-snapshot-.+[.]prom"}, "backup", "$1", "file", ".*/restic-snapshot-(.+)[.]prom")'';
              unit = "clocks";
              decimals = 0;
            }
          ];
        })
        (ui.stateTimeline {
          title = "Fresh";
          w = 9;
          h = 11;
          targets = [ (ui.target "max by (instance) (${backupStaleness})" "{{instance}}") ];
          threshold = ui.thresholds.goodWhenZero;
          valueMappings = ui.mappings.backupAge;
        })
      ];
    })

    (ui.row {
      title = "Load";
      collapsed = false;
      panels = [
        (ui.statusHistory {
          title = "CPU busy";
          description = "Share of CPU time that was not idle. Brighter is busier.";
          w = 12;
          h = 8;
          unit = "percent";
          threshold = ui.thresholds.cpuShades;
          targets = [ (ui.target (cpuBusy node) "{{instance}}") ];
        })
        (ui.statusHistory {
          title = "Pressure";
          description = "Share of time tasks waited for CPU, memory or disk, whichever was worst. Macs show their memory pressure level instead.";
          w = 12;
          h = 8;
          unit = "percent";
          threshold = ui.thresholds.pressureShades;
          targets = [
            (ui.target worstPressure "{{instance}}")
            (ui.target macMemoryPressure "{{instance}}")
          ];
          overrides = [
            (ui.queryOverride "B" {
              unit = "none";
              threshold = ui.thresholds.memoryPressureLevelShades;
              valueMappings = ui.mappings.memoryPressureLevelNames;
            })
          ];
        })
      ];
    })

    (ui.row {
      title = "Errors";
      panels = [
        (lines {
          title = "Errors";
          w = 24;
          h = 6;
          datasource = ui.loki;
          stackedBars = true;
          interval = "5m";
          targets = [
            (ui.lokiTarget "sum by (instance) (count_over_time(${journalErrors} [$__interval]))" "{{instance}}")
          ];
        })
        (ui.mergedTable {
          title = "Errors by message";
          description = "Count follows the picked time range. New marks a message that did not occur the day before.";
          w = 24;
          h = 10;
          datasource = ui.loki;
          sortBy = [
            {
              displayName = "New";
              desc = true;
            }
            {
              displayName = "Count";
              desc = true;
            }
          ];
          renamedColumns = {
            instance = "Host";
            service = "Service";
            message = "Message";
          };
          firstColumns = [
            "instance"
            "service"
            "message"
          ];
          labelColumns = {
            Host.width = 110;
            Service.width = 240;
          };
          columns = [
            {
              name = "Count";
              width = 80;
              expr = messageCount "[$__range]";
            }
            {
              name = "New";
              width = 70;
              expr = "count by (instance, service, message) ((${newMessages}) and ${messageCount "[$__range]"})";
              valueMappings = ui.mappings.new;
            }
          ];
        })
        (ui.logs {
          title = "Recent errors";
          w = 24;
          h = 12;
          expr = recentErrors;
        })
      ];
    })

    (ui.row {
      title = "Linux";
      panels = [
        (linesPerKind {
          title = "CPU clock, $kind";
          unit = "hertz";
          interval = "5m";
          targets = [ (ui.target cpuClock "{{instance}}") ];
        })
        (linesPerKind {
          title = "CPU pressure, $kind";
          unit = "percent";
          targets = [ (ui.target (pressure "cpu") "{{instance}}") ];
        })
        (linesPerKind {
          title = "Memory used, $kind";
          unit = "percent";
          targets = [ (ui.target (memoryUsed linux) "{{instance}}") ];
        })
        (linesPerKind {
          title = "Memory pressure, $kind";
          unit = "percent";
          targets = [ (ui.target (pressure "memory") "{{instance}}") ];
        })
        (linesPerKind {
          title = "Disk space used, $kind";
          unit = "percent";
          targets = [
            (ui.target ''100 * disk:used:ratio{${selected}, os="linux"}'' "{{instance}} {{disk}}")
          ];
        })
        (linesPerKind {
          title = "Disk I/O, $kind";
          unit = "Bps";
          targets = [ (ui.target (diskIo "${linux}, ${physicalDisks}") "{{instance}} {{device}}") ];
        })
        (ui.statusHistory {
          title = "Disk busy";
          w = 24;
          h = 12;
          unit = "percent";
          threshold = ui.thresholds.diskShades;
          targets = [
            # One label, machine then disk, so the rows sort that way.
            (ui.target ''max by (disk) (label_join(100 * rate(node_disk_io_time_seconds_total{${linux}, ${physicalDisks}}[$__rate_interval]), "disk", " ", "instance", "device"))'' "{{disk}}")
          ];
        })
        (linesPerKind {
          title = "I/O pressure, $kind";
          unit = "percent";
          targets = [ (ui.target (pressure "io") "{{instance}}") ];
        })
        (linesPerKind {
          title = "CPU temperature, $kind";
          unit = "celsius";
          interval = "5m";
          targets = [ (ui.target (cpuTemperature linux) "{{instance}}") ];
        })
        (linesPerKind {
          title = "Drive temperature, $kind";
          unit = "celsius";
          interval = "5m";
          targets = [
            (ui.target ''avg_over_time(smartctl_device_temperature{${smart}, os="linux", temperature_type="current"}[$__rate_interval])'' "{{instance}} {{device}}")
          ];
        })
        (linesPerKind {
          title = "Network traffic, $kind";
          unit = "bps";
          targets = [ (ui.target (networkTraffic linux) "{{instance}}") ];
        })
      ];
    })

    (ui.row {
      title = "macOS";
      panels = [
        (macLines {
          title = "CPU busy";
          unit = "percent";
          targets = [ (ui.target (cpuBusy macos) "{{instance}}") ];
        })
        (macLines {
          title = "Memory used";
          unit = "percent";
          targets = [ (ui.target (memoryUsed macos) "{{instance}}") ];
        })
        (ui.stateTimeline {
          title = "Memory pressure";
          w = 12;
          h = 8;
          targets = [ (ui.target macMemoryPressure "{{instance}}") ];
          threshold = ui.thresholds.memoryPressureLevel;
          valueMappings = ui.mappings.memoryPressureLevel;
        })
        (macLines {
          title = "Compressed memory";
          unit = "percent";
          targets = [
            (ui.target "100 * max by (instance) (node_memory_compressed_bytes{${macos}} / node_memory_total_bytes{${macos}})" "{{instance}}")
          ];
        })
        (macLines {
          title = "Paging";
          unit = "Bps";
          targets = [ (ui.target paging "{{instance}}") ];
        })
        (macLines {
          title = "Disk space used";
          unit = "percent";
          targets = [ (ui.target ''100 * disk:used:ratio{${selected}, os="macos"}'' "{{instance}}") ];
        })
        # disk0 is a Mac's internal SSD; the higher numbers are disk images and external drives.
        (macLines {
          title = "Disk I/O";
          unit = "Bps";
          targets = [ (ui.target (diskIo ''${macos}, device="disk0"'') "{{instance}}") ];
        })
        (macLines {
          title = "Network traffic";
          unit = "bps";
          targets = [ (ui.target (networkTraffic macos) "{{instance}}") ];
        })
      ];
    })

    (ui.row {
      title = "Drives";
      panels = [
        (ui.mergedTable {
          title = "Drive health";
          w = 24;
          # Fifteen drives today, plus the title and the header.
          h = 17;
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns = {
            instance = "Host";
            device = "Drive";
            model_name = "Model";
          };
          firstColumns = [
            "instance"
            "device"
            "model_name"
          ];
          columns = [
            {
              name = "Temp";
              width = 110;
              expr = drive ''smartctl_device_temperature{${smart}, temperature_type="current"}'';
              unit = "celsius";
            }
            {
              name = "Wear";
              width = 110;
              expr = drive "smartctl_device_percentage_used{${smart}}";
              unit = "percent";
              threshold = ui.thresholds.wear;
            }
            {
              name = "Errors";
              width = 110;
              expr = drive driveErrors;
              threshold = ui.thresholds.goodWhenZero;
            }
            {
              name = "SMART";
              width = 110;
              expr = drive "smartctl_device_smart_status{${smart}}";
              threshold = ui.thresholds.goodWhenOne;
              valueMappings = ui.mappings.passed;
            }
          ];
        })
      ];
    })

    (ui.row {
      title = "Uptime";
      panels = [
        # Servers only: a laptop asleep is normal.
        (ui.stateTimeline {
          title = "Up";
          w = 24;
          # Half a grid unit per server, plus the title: thin rows.
          h = builtins.length (machinesByKind.server or [ ]) / 2 + 2;
          targets = [ (ui.target (up "server") "{{instance}}") ];
          threshold = ui.thresholds.goodWhenOne;
          valueMappings = ui.mappings.upDown;
        })
        (ui.mergedTable {
          title = "Last boot and shutdown";
          w = 24;
          # A grid unit per Linux machine, plus the title and the header.
          h = linuxMachineCount + 2;
          sortBy = [
            {
              displayName = "Host";
              desc = false;
            }
          ];
          renamedColumns.instance = "Host";
          # Ready and Finished count from the start of the kernel; Finished waits for catch-up jobs such as a missed backup.
          columns = [
            {
              name = "Ready";
              expr = bootReading "boot_ready_seconds";
              unit = "s";
            }
            {
              name = "Finished";
              expr = bootReading "boot_finished_seconds";
              unit = "s";
            }
            {
              name = "Firmware + loader";
              expr = ''sum by (instance) (boot_phase_seconds{${linux}, phase=~"firmware|loader"})'';
              unit = "s";
            }
            {
              name = "Last shutdown";
              expr = bootReading "shutdown_seconds";
              unit = "s";
            }
            {
              name = "Slowest start";
              expr = bootReading "boot_unit_start_seconds";
              unit = "s";
            }
            {
              name = "Slowest stop";
              expr = bootReading "shutdown_unit_stop_seconds";
              unit = "s";
            }
          ];
        })
        (slowestUnits {
          title = "Slowest starts";
          metric = "boot_unit_start_seconds";
        })
        (slowestUnits {
          title = "Slowest stops";
          metric = "shutdown_unit_stop_seconds";
        })
      ];
    })
  ];
}

{
  lib,
  alwaysOn,
  machineRules,
}:
let
  severities = [
    "critical"
    "warning"
  ];

  checkSeverity =
    machine: rule:
    if rule ? alert && !(lib.elem (rule.labels.severity or null) severities) then
      throw "@adeci/monitoring: alert ${rule.alert} from ${machine} needs labels.severity set to one of: ${lib.concatStringsSep ", " severities}"
    else
      rule;

  onlyAlwaysOn = expression: "(${expression}) and on (instance) instance:always_on";

  # Disks only: tmpfs, ramfs and FUSE mounts come and go with whoever uses them.
  disk = ''fstype=~"ext[234]|btrfs|xfs|f2fs|bcachefs|zfs|vfat"'';
  freeRatio = "node_filesystem_avail_bytes{${disk}} / node_filesystem_size_bytes{${disk}}";
  # Read-only bind mounts such as the Nix store would repeat their filesystem's alerts.
  writable = "on (instance, mountpoint) node_filesystem_readonly == 0";

  alwaysOnRecords = map (instance: {
    record = "instance:always_on";
    expr = "vector(1)";
    labels = { inherit instance; };
  }) alwaysOn;

  fleetAlerts = [
    {
      alert = "HostDown";
      # Agents push their metrics, so a machine that is gone has no `up` series rather than `up == 0`.
      expr = "instance:always_on unless on (instance) present_over_time(up[5m])";
      for = "5m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.instance }} is down";
        description = "No metrics from {{ $labels.instance }} for 10 minutes.";
      };
    }
    {
      alert = "SystemdUnitFailed";
      # Transient systemd-run units and user managers are not services.
      expr = onlyAlwaysOn ''node_systemd_unit_state{state="failed", name!~"run-.+|user@.+"} == 1'';
      for = "10m";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.name }} failed on {{ $labels.instance }}";
        description = "See `systemctl status {{ $labels.name }}` on {{ $labels.instance }}.";
      };
    }
    {
      alert = "FilesystemFillingUp";
      expr = onlyAlwaysOn ''
        ${freeRatio} < 0.1
        and predict_linear(node_filesystem_avail_bytes{${disk}}[1d], 24 * 3600) < 0
        and ${writable}
      '';
      for = "1h";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} fills up within a day";
        description = "{{ $value | humanizePercentage }} free, shrinking at the last day's rate.";
      };
    }
    {
      alert = "FilesystemFillingUp";
      expr = onlyAlwaysOn ''
        ${freeRatio} < 0.1
        and predict_linear(node_filesystem_avail_bytes{${disk}}[6h], 4 * 3600) < 0
        and ${writable}
      '';
      for = "30m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} fills up within hours";
        description = "{{ $value | humanizePercentage }} free, shrinking at the last 6 hours' rate.";
      };
    }
    {
      alert = "FilesystemAlmostFull";
      expr = onlyAlwaysOn ''
        ${freeRatio} < 0.05
        and node_filesystem_avail_bytes{${disk}} < 10 * 1024 ^ 3
        and ${writable}
      '';
      for = "15m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} is almost full";
        description = "Only {{ $value | humanizePercentage }} free.";
      };
    }
    {
      alert = "FilesystemOutOfInodes";
      expr = onlyAlwaysOn ''
        node_filesystem_files_free{${disk}} / node_filesystem_files{${disk}} < 0.05
        and ${writable}
      '';
      for = "15m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} is running out of inodes";
        description = "Only {{ $value | humanizePercentage }} of its inodes are free.";
      };
    }
    {
      alert = "FilesystemReadOnly";
      # A filesystem whose every mount is read-only, as after the kernel remounts it on errors.
      expr = onlyAlwaysOn ''
        max by (instance, device) (
          node_filesystem_readonly{${disk}} == 1
          unless on (instance, device) node_filesystem_readonly == 0
        )
      '';
      for = "5m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.device }} on {{ $labels.instance }} is read-only";
        description = "Every mount of {{ $labels.device }} is read-only, as after the kernel remounts a failing disk; check `dmesg`.";
      };
    }
    {
      alert = "MemoryErrors";
      expr = onlyAlwaysOn ''
        increase(node_edac_uncorrectable_errors_total[1h]) > 0
        or node_memory_HardwareCorrupted_bytes > 0
      '';
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.instance }} has uncorrectable memory errors";
        description = "ECC found errors it could not correct, or the kernel retired corrupted pages; replace the failing memory.";
      };
    }
    {
      alert = "MemoryErrors";
      expr = onlyAlwaysOn "increase(node_edac_correctable_errors_total[1d]) > 10";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.instance }} keeps correcting memory errors";
        description = "{{ $value | humanize }} corrected errors on memory controller {{ $labels.controller }} in the last day; a module may be failing.";
      };
    }
    {
      alert = "HardwareTooHot";
      expr = onlyAlwaysOn ''
        node_hwmon_temp_celsius
          >= on (instance, chip, sensor) (node_hwmon_temp_crit_celsius > 0) - 5
      '';
      for = "10m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.instance }} is overheating";
        description = "{{ $labels.chip }} {{ $labels.sensor }} is at {{ $value }}°C, within 5°C of its critical limit.";
      };
    }
    {
      alert = "BackupStale";
      expr = onlyAlwaysOn ''
        time() - node_systemd_timer_last_trigger_seconds{name=~"(restic-backups|borgbackup-job)-.+\\.timer"} > 36 * 3600
        and node_systemd_timer_last_trigger_seconds > 0
      '';
      for = "30m";
      labels.severity = "warning";
      annotations = {
        summary = "Backups on {{ $labels.instance }} are stale";
        description = "{{ $labels.name }} last fired {{ $value | humanizeDuration }} ago.";
      };
    }
    {
      alert = "CertificateExpiring";
      expr = onlyAlwaysOn "acme_certificate_expiry_timestamp_seconds - time() < 14 * 86400";
      for = "1h";
      labels.severity = "warning";
      annotations = {
        summary = "Certificate {{ $labels.certificate }} on {{ $labels.instance }} expires soon";
        description = "It expires in {{ $value | humanizeDuration }}, so its renewal is failing.";
      };
    }
    {
      alert = "ConntrackTableFilling";
      expr = onlyAlwaysOn "node_nf_conntrack_entries / node_nf_conntrack_entries_limit > 0.8";
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "Connection tracking on {{ $labels.instance }} is nearly full";
        description = "{{ $value | humanizePercentage }} of the table is in use; new connections are dropped once it is full.";
      };
    }
    {
      alert = "NetworkInterfaceErrors";
      expr = onlyAlwaysOn ''
        rate(node_network_receive_errs_total[15m]) + rate(node_network_transmit_errs_total[15m]) > 0.05
      '';
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.device }} on {{ $labels.instance }} has errors";
        description = "{{ $value | humanize }} errors/s; check the cable, transceiver and switch port.";
      };
    }
    {
      alert = "ExporterDown";
      expr = onlyAlwaysOn "up == 0";
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.job }} metrics from {{ $labels.instance }} are missing";
        description = "Scraping {{ $labels.job }} on {{ $labels.instance }} fails, so its dashboards and alerts are blind.";
      };
    }
    {
      alert = "TextfileMetricsStale";
      expr = onlyAlwaysOn ''
        node_textfile_scrape_error == 1
        or time() - node_textfile_mtime_seconds > 3600
      '';
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "Metrics files on {{ $labels.instance }} are stale";
        description = "A `*.prom` file in the textfile directory{{ with $labels.file }} ({{ . }}){{ end }} is unreadable or over an hour old.";
      };
    }
    {
      alert = "TelemetryDropped";
      expr = onlyAlwaysOn ''
        sum by (instance) (rate(prometheus_remote_storage_samples_failed_total[15m])) > 0
        or sum by (instance) (rate(loki_write_dropped_entries_total[15m])) > 0
      '';
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.instance }} is losing metrics or logs";
        description = "Its agent fails to ship samples or drops log lines; check alloy.service there.";
      };
    }
  ];

  serverAlerts = [
    {
      alert = "RuleEvaluationFailing";
      expr = "increase(prometheus_rule_evaluation_failures_total[10m]) > 0";
      labels.severity = "warning";
      annotations = {
        summary = "Alert rules fail to evaluate";
        description = "Rules in {{ $labels.rule_group }} fail, so their alerts can't fire; check the Prometheus log on {{ $labels.instance }}.";
      };
    }
    {
      alert = "LogIngestFailing";
      expr = ''
        sum by (instance) (rate(loki_request_duration_seconds_count{route=~"api_prom_push|loki_api_v1_push", status_code=~"5.."}[5m])) > 0
      '';
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "Loki rejects pushed logs";
        description = "Pushes to Loki on {{ $labels.instance }} fail with server errors, so logs are being lost.";
      };
    }
  ];
in
{
  fleet.groups = [
    {
      name = "fleet";
      rules = alwaysOnRecords ++ fleetAlerts;
    }
    {
      name = "monitoring-server";
      rules = serverAlerts;
    }
  ];

  machines.groups = lib.mapAttrsToList (machine: rules: {
    name = machine;
    rules = map (checkSeverity machine) rules;
  }) (lib.filterAttrs (_: rules: rules != [ ]) machineRules);
}

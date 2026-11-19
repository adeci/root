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
  # Machines that are not always on: laptops and handhelds.
  onlyLaptops = expression: "(${expression}) unless on (instance) instance:always_on";

  disk = import ./disks.nix;
  freeRatio = "node_filesystem_avail_bytes{${disk}} / node_filesystem_size_bytes{${disk}}";
  # Read-only bind mounts such as the Nix store would repeat their filesystem's alerts.
  writable = "on (instance, mountpoint) node_filesystem_readonly == 0";

  # The agent asks each repository for its newest snapshot every hour; 0 while there is none.
  snapshotAge = "time() - restic_snapshot_timestamp_seconds";
  staleBackup = "The newest snapshot in its {{ $labels.backup }} repository is {{ $value | humanizeDuration }} old; see `systemctl status restic-backups-{{ $labels.backup }}` on {{ $labels.instance }}.";
  # A laptop's newest snapshot as it last reported it, so a night asleep keeps its alerts.
  laptopSnapshot = "last_over_time(restic_snapshot_timestamp_seconds[1d] @ end())";
  # How long a laptop has been on since that snapshot: the half hours of the last 30 days in which it reported it.
  laptopSnapshotAge = "count_over_time((restic_snapshot_timestamp_seconds == ${laptopSnapshot})[30d:30m]) * 1800";
  staleLaptopBackup = "It has been on for {{ $value | humanizeDuration }} of the last 30 days since the newest snapshot in its {{ $labels.backup }} repository. It backs up only on AC power, on a network that is not metered and with the repository answering; `journalctl -u restic-{{ $labels.backup }}-when-due` on {{ $labels.instance }} says what was missing.";

  alwaysOnRecords = map (instance: {
    record = "instance:always_on";
    expr = "vector(1)";
    labels = { inherit instance; };
  }) alwaysOn;

  # A data filesystem: a disk, not the small /boot partition beside it.
  dataFilesystem = ''job="node", ${disk}, mountpoint!~"/boot(/.*)?"'';

  diskRecords = [
    # The physical disk under each filesystem device: the agent's map on Linux, the device name on a Mac.
    {
      record = "device:disk:info";
      expr = ''
        max by (instance, os, kind, device, disk) (node_filesystem_disk_info{job="node"})
        or label_replace(group by (instance, os, kind, device) (node_filesystem_size_bytes{job="node", os="macos"}), "disk", "$1", "device", "/dev/(disk[0-9]+)s.*")
      '';
    }
    # How full each physical disk is: its fullest data filesystem.
    {
      record = "disk:used:ratio";
      expr = ''
        max by (instance, os, kind, disk) (
          (1 - node_filesystem_avail_bytes{${dataFilesystem}} / node_filesystem_size_bytes{${dataFilesystem}})
          * on (instance, device) group_left (disk) device:disk:info
        )
      '';
    }
  ];

  fleetAlerts = [
    {
      alert = "HostDown";
      expr = onlyAlwaysOn ''up{job="node"} == 0'';
      for = "5m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.instance }} is down";
        description = "The server hasn't reached node_exporter on {{ $labels.instance }} for 5 minutes.";
      };
    }
    {
      alert = "PublicNameDown";
      # Whatever serves it: a name's instance need not be an always-on machine.
      expr = "probe_success == 0";
      for = "5m";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.name }} does not answer";
        description = "Requests to {{ $labels.name }}, which {{ $labels.instance }} serves, have failed for 5 minutes; see Public names on the fleet page.";
      };
    }
    {
      alert = "TunnelDown";
      # No connection to Cloudflare, or no cloudflared to make one.
      expr = onlyAlwaysOn ''cloudflared_tunnel_ha_connections == 0 or up{job="cloudflared"} == 0'';
      for = "5m";
      labels.severity = "critical";
      annotations = {
        summary = "The Cloudflare tunnel of {{ $labels.instance }} is down";
        description = "cloudflared on {{ $labels.instance }} has no connection to Cloudflare, so the public names it serves don't answer; see `systemctl status 'cloudflared-tunnel-*'` there.";
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
      expr = onlyAlwaysOn "${snapshotAge} > 36 * 3600";
      labels.severity = "warning";
      annotations = {
        summary = "The newest backup of {{ $labels.instance }} is over a day and a half old";
        description = staleBackup;
      };
    }
    {
      alert = "BackupStale";
      expr = onlyAlwaysOn "${snapshotAge} > 72 * 3600";
      labels.severity = "critical";
      annotations = {
        summary = "The newest backup of {{ $labels.instance }} is over three days old";
        description = staleBackup;
      };
    }
    {
      alert = "LaptopBackupStale";
      # Or a snapshot older than those 30 days on a laptop on for a day of them, which the count alone never reaches at an hour or two a day.
      expr = onlyLaptops "${laptopSnapshotAge} > 3 * 86400 or (${laptopSnapshotAge} >= 86400 and time() - ${laptopSnapshot} > 30 * 86400)";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.instance }} has gone days of use without a backup";
        description = staleLaptopBackup;
      };
    }
    {
      alert = "LaptopBackupStale";
      expr = onlyLaptops "${laptopSnapshotAge} > 7 * 86400";
      labels.severity = "critical";
      annotations = {
        summary = "{{ $labels.instance }} has gone a week of use without a backup";
        description = staleLaptopBackup;
      };
    }
    {
      alert = "BackupFailed";
      # On an always-on machine it is a SystemdUnitFailed; a laptop asleep keeps the state it last reported.
      expr = onlyLaptops ''last_over_time(node_systemd_unit_state{name=~"restic-backups-.+[.]service", state="failed"}[1d]) == 1'';
      # The hourly retry clears the failed state while it runs.
      keep_firing_for = "1h";
      labels.severity = "warning";
      annotations = {
        summary = "The last backup of {{ $labels.instance }} failed";
        description = "See `journalctl -u {{ $labels.name }}` on {{ $labels.instance }}; it is tried again every hour.";
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
      alert = "TailscaleKeyExpiring";
      expr = onlyAlwaysOn "tailscale_key_expiry_timestamp_seconds - time() < 14 * 86400";
      for = "1h";
      labels.severity = "warning";
      annotations = {
        summary = "The Tailscale key of {{ $labels.instance }} expires soon";
        description = "It expires in {{ $value | humanizeDuration }}, and the machine then leaves the tailnet; sign it in again, or turn off key expiry for it in the admin console.";
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
        description = ''{{ $value | printf "%.2f" }} errors/s; check the cable, transceiver and switch port.'';
      };
    }
    {
      alert = "ExporterDown";
      # node_exporter has HostDown and cloudflared TunnelDown; a probe that can't be scraped is its prober's blackbox job down.
      expr = onlyAlwaysOn ''up{job!~"node|cloudflared|probe"} == 0'';
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "{{ $labels.job }} metrics from {{ $labels.instance }} are missing";
        description = "Scraping {{ $labels.job }} on {{ $labels.instance }} fails, so its dashboards and alerts are blind.";
      };
    }
    {
      alert = "DriveDegrading";
      # A count that stays put is the owner's call; one that grows, or a failed self-assessment, is news.
      expr = onlyAlwaysOn ''
        delta(smartctl_device_attribute{attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable", attribute_value_type="raw"}[1d]) > 0
        or smartctl_device_smart_status == 0
      '';
      labels.severity = "warning";
      annotations = {
        summary = "Drive {{ $labels.device }} in {{ $labels.instance }} is degrading";
        description = "Its bad-sector counts grew in the last day, or SMART says it failed; see its row under Drives on the fleet page, and `smartctl -a` on {{ $labels.instance }}.";
      };
    }
    {
      alert = "TextfileMetricsStale";
      # The disk map, what the system runs and the boot timing are written only at boot and deploy; the slowest of the rest every hour.
      expr = onlyAlwaysOn ''
        node_textfile_scrape_error == 1
        or time() - node_textfile_mtime_seconds{file!~".*/(filesystem-disks|system-version|boot-timing)[.]prom"} > 2 * 3600
      '';
      for = "15m";
      labels.severity = "warning";
      annotations = {
        summary = "Metrics files on {{ $labels.instance }} are stale";
        description = "A `*.prom` file in the textfile directory{{ with $labels.file }} ({{ . }}){{ end }} is unreadable or over two hours old.";
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
    {
      alert = "AlertDeliveryFailing";
      # Alertmanager retries an undelivered notification every 5 minutes: the window always holds the next failure while delivery is broken, and drops a lone one well within the 15 minutes.
      expr = "sum without (reason) (rate(alertmanager_notifications_failed_total[7m])) > 0";
      for = "15m";
      labels.severity = "critical";
      annotations = {
        summary = "Alert notifications fail to send";
        description = "Sending {{ $labels.integration }} notifications fails, so alerts go unseen; check the Alertmanager log on {{ $labels.instance }}.";
      };
    }
  ];
in
{
  fleet.groups = [
    {
      name = "fleet";
      rules = alwaysOnRecords ++ diskRecords ++ fleetAlerts;
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

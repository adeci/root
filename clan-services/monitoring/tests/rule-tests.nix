# "server" is always-on, "laptop" is not.
let
  noAlert = alertname: time: {
    inherit alertname;
    eval_time = time;
    exp_alerts = [ ];
  };

  firing = alertname: time: alerts: {
    inherit alertname;
    eval_time = time;
    exp_alerts = alerts;
  };

  serverDown = {
    exp_labels = {
      instance = "server";
      job = "node";
      severity = "critical";
    };
    exp_annotations = {
      summary = "server is down";
      description = "The server hasn't reached node_exporter on server for 5 minutes.";
    };
  };

  tunnelDown = {
    exp_labels = {
      instance = "server";
      job = "cloudflared";
      severity = "critical";
    };
    exp_annotations = {
      summary = "The Cloudflare tunnel of server is down";
      description = "cloudflared on server has no connection to Cloudflare, so its public names don't answer; see `systemctl status 'cloudflared-tunnel-*'` there.";
    };
  };

  laptopBackupFailed = {
    exp_labels = {
      instance = "laptop";
      name = "restic-backups-state.service";
      state = "failed";
      severity = "warning";
    };
    exp_annotations = {
      summary = "The last backup of laptop failed";
      description = "See `journalctl -u restic-backups-state.service` on laptop; it is tried again every hour.";
    };
  };
in
[
  {
    name = "a server is down after 5 minutes without node_exporter, not when another exporter is; a laptop never is";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="node"}'';
        values = "1x10 0x30";
      }
      {
        series = ''up{instance="server", job="smartctl"}'';
        values = "0x30";
      }
      {
        series = ''up{instance="laptop", job="node"}'';
        values = "1x10 0x30";
      }
    ];
    alert_rule_test = [
      (noAlert "HostDown" "15m")
      (firing "HostDown" "17m" [ serverDown ])
    ];
  }

  {
    name = "a public name that stops answering alerts after 5 minutes, whatever serves it";
    interval = "1m";
    input_series = [
      {
        series = ''probe_success{job="probe", instance="server", name="app.example.com"}'';
        values = "1x5 0x20";
      }
      {
        series = ''probe_success{job="probe", instance="cloudflare", name="go.example.com"}'';
        values = "1x5 0x20";
      }
    ];
    alert_rule_test =
      let
        down = name: instance: {
          exp_labels = {
            inherit name instance;
            job = "probe";
            severity = "critical";
          };
          exp_annotations = {
            summary = "${name} does not answer";
            description = "Requests to ${name}, served by ${instance}, have failed for 5 minutes; see Public names on the fleet page.";
          };
        };
      in
      [
        (noAlert "PublicNameDown" "10m")
        (firing "PublicNameDown" "12m" [
          (down "app.example.com" "server")
          (down "go.example.com" "cloudflare")
        ])
      ];
  }

  {
    name = "an unscrapable prober is one ExporterDown, not one per probe";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="blackbox"}'';
        values = "0x30";
      }
      {
        series = ''up{instance="server", job="probe", name="app.example.com"}'';
        values = "0x30";
      }
    ];
    alert_rule_test = [
      (firing "ExporterDown" "20m" [
        {
          exp_labels = {
            instance = "server";
            job = "blackbox";
            severity = "warning";
          };
          exp_annotations = {
            summary = "blackbox metrics from server are missing";
            description = "Scraping blackbox on server fails, so its dashboards and alerts are blind.";
          };
        }
      ])
    ];
  }

  {
    name = "a tunnel is down after 5 minutes without a connection to Cloudflare";
    interval = "1m";
    input_series = [
      {
        series = ''cloudflared_tunnel_ha_connections{instance="server", job="cloudflared"}'';
        values = "4x5 0x20";
      }
      {
        series = ''up{instance="server", job="cloudflared"}'';
        values = "1x25";
      }
    ];
    alert_rule_test = [
      (noAlert "TunnelDown" "10m")
      (firing "TunnelDown" "12m" [ tunnelDown ])
    ];
  }

  {
    name = "a stopped cloudflared is TunnelDown, not ExporterDown";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="cloudflared"}'';
        values = "1x5 0x30";
      }
    ];
    alert_rule_test = [
      (firing "TunnelDown" "12m" [ tunnelDown ])
      (noAlert "ExporterDown" "30m")
    ];
  }

  {
    name = "a Tailscale key warns two weeks before it expires";
    interval = "1m";
    input_series = [
      {
        series = ''tailscale_key_expiry_timestamp_seconds{instance="server"}'';
        values = "1296000x1600";
      }
    ];
    alert_rule_test = [
      (noAlert "TailscaleKeyExpiring" "23h")
      (firing "TailscaleKeyExpiring" "26h" [
        {
          exp_labels = {
            instance = "server";
            severity = "warning";
          };
          exp_annotations = {
            summary = "The Tailscale key of server expires soon";
            description = "It expires in 13d 22h 0m 0s, then the machine leaves the tailnet; sign it in again or turn off its key expiry in the admin console.";
          };
        }
      ])
    ];
  }

  {
    name = "failed units alert on servers, not on laptops or for transient units";
    interval = "1m";
    input_series = [
      {
        series = ''node_systemd_unit_state{instance="server", name="backup.service", state="failed"}'';
        values = "1x30";
      }
      {
        series = ''node_systemd_unit_state{instance="server", name="run-p42-i43.service", state="failed"}'';
        values = "1x30";
      }
      {
        series = ''node_systemd_unit_state{instance="laptop", name="backup.service", state="failed"}'';
        values = "1x30";
      }
    ];
    alert_rule_test = [
      (noAlert "SystemdUnitFailed" "9m")
      (firing "SystemdUnitFailed" "11m" [
        {
          exp_labels = {
            instance = "server";
            name = "backup.service";
            state = "failed";
            severity = "warning";
          };
          exp_annotations = {
            summary = "backup.service failed on server";
            description = "See `systemctl status backup.service` on server.";
          };
        }
      ])
    ];
  }

  {
    name = "a reverted deploy warns, and its file is never stale";
    interval = "1m";
    input_series = [
      {
        series = ''deploy_guard_revert_timestamp_seconds{instance="server", job="node"}'';
        values = "_x10 660x170";
      }
      {
        series = ''node_textfile_mtime_seconds{instance="server", job="node", file="/var/lib/prometheus-node-exporter/textfile/deploy-guard.prom"}'';
        values = "660x180";
      }
    ];
    alert_rule_test = [
      (firing "DeployReverted" "11m" [
        {
          exp_labels = {
            instance = "server";
            job = "node";
            severity = "warning";
          };
          exp_annotations = {
            summary = "server went back to its previous system";
            description = "A switch on server wasn't confirmed in time, so it went back to its previous system until a switch is confirmed; see `journalctl -u deploy-guard-revert` there.";
          };
        }
      ])
      (noAlert "TextfileMetricsStale" "175m")
    ];
  }

  {
    name = "a server's disk warns a day before it fills and is critical hours before, almost full or out of inodes; a laptop and the read-only bind mount stay quiet";
    interval = "5m";
    input_series =
      let
        # 9% free of 100 GB, losing 600 MB an hour, and 4% of its inodes free.
        mount = instance: mountpoint: readonly: [
          {
            series = ''node_filesystem_avail_bytes{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "9000000000-50000000x144";
          }
          {
            series = ''node_filesystem_size_bytes{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "100000000000x144";
          }
          {
            series = ''node_filesystem_readonly{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "${readonly}x144";
          }
          {
            series = ''node_filesystem_files_free{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "40000x144";
          }
          {
            series = ''node_filesystem_files{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "1000000x144";
          }
        ];
      in
      mount "server" "/" "0" ++ mount "server" "/nix/store" "1" ++ mount "laptop" "/" "0";
    alert_rule_test =
      let
        # An alert on server's root filesystem.
        root = severity: summary: description: {
          exp_labels = {
            instance = "server";
            device = "/dev/sda1";
            fstype = "ext4";
            mountpoint = "/";
            inherit severity;
          };
          exp_annotations = { inherit summary description; };
        };
      in
      [
        (noAlert "FilesystemFillingUp" "60m")
        (firing "FilesystemFillingUp" "3h" [
          (root "warning" "/ on server fills up within a day" "7.2% free, shrinking at the last day's rate.")
        ])
        (noAlert "FilesystemAlmostFull" "3h")
        # Within 4 hours of full since 11h.
        (firing "FilesystemFillingUp" "12h" [
          (root "warning" "/ on server fills up within a day" "1.8% free, shrinking at the last day's rate.")
          (root "critical" "/ on server fills up within hours"
            "1.8% free, shrinking at the last 6 hours' rate."
          )
        ])
        (firing "FilesystemAlmostFull" "12h" [
          (root "critical" "/ on server is almost full" "Only 1.8% free.")
        ])
        (firing "FilesystemOutOfInodes" "12h" [
          (root "critical" "/ on server is running out of inodes" "Only 4% of its inodes are free.")
        ])
      ];
  }

  {
    name = "a filesystem is read-only only when all its mounts are";
    interval = "1m";
    input_series = [
      {
        series = ''node_filesystem_readonly{instance="server", device="/dev/sda1", fstype="ext4", mountpoint="/"}'';
        values = "1x10";
      }
      {
        series = ''node_filesystem_readonly{instance="server", device="/dev/sdb1", fstype="ext4", mountpoint="/data"}'';
        values = "0x10";
      }
      {
        series = ''node_filesystem_readonly{instance="server", device="/dev/sdb1", fstype="ext4", mountpoint="/data/store"}'';
        values = "1x10";
      }
      {
        series = ''node_filesystem_readonly{instance="laptop", device="/dev/sda1", fstype="ext4", mountpoint="/"}'';
        values = "1x10";
      }
    ];
    alert_rule_test = [
      (firing "FilesystemReadOnly" "6m" [
        {
          exp_labels = {
            instance = "server";
            device = "/dev/sda1";
            severity = "critical";
          };
          exp_annotations = {
            summary = "/dev/sda1 on server is read-only";
            description = "Every mount of /dev/sda1 is read-only, as after the kernel remounts a failing disk; check `dmesg`.";
          };
        }
      ])
    ];
  }

  {
    name = "a server's backup warns at 36 hours old and is critical at 72";
    interval = "1h";
    input_series = [
      {
        series = ''restic_snapshot_timestamp_seconds{instance="server", backup="state"}'';
        values = "0x80";
      }
      {
        series = ''restic_snapshot_timestamp_seconds{instance="laptop", backup="state"}'';
        values = "0x80";
      }
    ];
    alert_rule_test =
      let
        stale = severity: summary: age: {
          exp_labels = {
            instance = "server";
            backup = "state";
            inherit severity;
          };
          exp_annotations = {
            inherit summary;
            description = "The newest snapshot in its state repository is ${age} old; see `systemctl status restic-backups-state` on server.";
          };
        };
        warning = stale "warning" "The newest backup of server is over a day and a half old";
        critical = stale "critical" "The newest backup of server is over three days old";
      in
      [
        (noAlert "BackupStale" "36h")
        (firing "BackupStale" "37h" [ (warning "1d 13h 0m 0s") ])
        (firing "BackupStale" "73h" [
          (warning "3d 1h 0m 0s")
          (critical "3d 1h 0m 0s")
        ])
      ];
  }

  {
    name = "a laptop's failed backup fires until an hour after a success; a server's is a failed unit";
    interval = "1m";
    input_series = [
      {
        series = ''node_systemd_unit_state{instance="laptop", name="restic-backups-state.service", state="failed"}'';
        # Failed, then tried again an hour later with success.
        values = "0x5 1x60 0x120";
      }
      {
        series = ''node_systemd_unit_state{instance="server", name="restic-backups-state.service", state="failed"}'';
        values = "1x180";
      }
    ];
    alert_rule_test = [
      (firing "BackupFailed" "7m" [ laptopBackupFailed ])
      (firing "BackupFailed" "100m" [ laptopBackupFailed ])
      (noAlert "BackupFailed" "130m")
    ];
  }

  {
    name = "a laptop whose key is refused fails every hourly retry and stays reported, a night asleep included";
    interval = "1m";
    input_series = [
      {
        series = ''node_systemd_unit_state{instance="laptop", name="restic-backups-state.service", state="failed"}'';
        # Fails every hourly retry, sleeps ten hours, still failed on waking.
        values = "0x5 1x54 0x3 1x54 0x3 1x54 _x600 1x30";
      }
    ];
    alert_rule_test = [ (firing "BackupFailed" "500m" [ laptopBackupFailed ]) ];
  }

  {
    name = "a drive warns on growing bad sectors or failed SMART, not on a steady count";
    interval = "1h";
    input_series = [
      {
        series = ''smartctl_device_attribute{instance="server", device="sdd", attribute_name="Offline_Uncorrectable", attribute_value_type="raw"}'';
        values = "30x24 32x30";
      }
      {
        series = ''smartctl_device_smart_status{instance="server", device="nvme0"}'';
        values = "1x40 0x14";
      }
    ];
    alert_rule_test = [
      (firing "DriveDegrading" "30h" [
        {
          exp_labels = {
            instance = "server";
            device = "sdd";
            attribute_name = "Offline_Uncorrectable";
            attribute_value_type = "raw";
            severity = "warning";
          };
          exp_annotations = {
            summary = "Drive sdd in server is degrading";
            description = "Bad-sector counts grew in the last day, or SMART failed; see Drives on the fleet page and `smartctl -a` on server.";
          };
        }
      ])
      (firing "DriveDegrading" "50h" [
        {
          exp_labels = {
            instance = "server";
            device = "nvme0";
            severity = "warning";
          };
          exp_annotations = {
            summary = "Drive nvme0 in server is degrading";
            description = "Bad-sector counts grew in the last day, or SMART failed; see Drives on the fleet page and `smartctl -a` on server.";
          };
        }
      ])
    ];
  }

  {
    name = "certificates warn two weeks before they expire";
    interval = "1m";
    input_series = [
      {
        series = ''acme_certificate_expiry_timestamp_seconds{instance="server", certificate="soon.example"}'';
        values = "864000x120";
      }
      {
        series = ''acme_certificate_expiry_timestamp_seconds{instance="server", certificate="later.example"}'';
        values = "5184000x120";
      }
    ];
    alert_rule_test = [
      (firing "CertificateExpiring" "2h" [
        {
          exp_labels = {
            instance = "server";
            certificate = "soon.example";
            severity = "warning";
          };
          exp_annotations = {
            summary = "Certificate soon.example on server expires soon";
            description = "It expires in 9d 22h 0m 0s, so its renewal is failing.";
          };
        }
      ])
    ];
  }

  {
    name = "sensors near their critical limit alert, sensors without a limit do not";
    interval = "1m";
    input_series = [
      {
        series = ''node_hwmon_temp_celsius{instance="server", chip="cpu", sensor="temp1"}'';
        values = "97x20";
      }
      {
        series = ''node_hwmon_temp_crit_celsius{instance="server", chip="cpu", sensor="temp1"}'';
        values = "100x20";
      }
      {
        series = ''node_hwmon_temp_celsius{instance="server", chip="nvme", sensor="temp1"}'';
        values = "60x20";
      }
      {
        series = ''node_hwmon_temp_crit_celsius{instance="server", chip="nvme", sensor="temp1"}'';
        values = "0x20";
      }
      {
        series = ''node_hwmon_temp_celsius{instance="laptop", chip="cpu", sensor="temp1"}'';
        values = "99x20";
      }
      {
        series = ''node_hwmon_temp_crit_celsius{instance="laptop", chip="cpu", sensor="temp1"}'';
        values = "100x20";
      }
    ];
    alert_rule_test = [
      (firing "HardwareTooHot" "11m" [
        {
          exp_labels = {
            instance = "server";
            chip = "cpu";
            sensor = "temp1";
            severity = "critical";
          };
          exp_annotations = {
            summary = "server is overheating";
            description = "cpu temp1 is at 97°C, within 5°C of its critical limit.";
          };
        }
      ])
    ];
  }

  {
    name = "a notification failing at every 5-minute retry alerts after 15 minutes";
    interval = "1m";
    input_series = [
      {
        series = ''alertmanager_notifications_failed_total{instance="server", job="alertmanager", integration="webhook", reason="serverError"}'';
        values = "0x14 1x4 2x4 3x4 4x4 5x4 6x4 7x4";
      }
    ];
    alert_rule_test = [
      (noAlert "AlertDeliveryFailing" "29m")
      (firing "AlertDeliveryFailing" "31m" [
        {
          exp_labels = {
            instance = "server";
            job = "alertmanager";
            integration = "webhook";
            severity = "critical";
          };
          exp_annotations = {
            summary = "Alert notifications fail to send";
            description = "Sending webhook notifications fails, so alerts go unseen; check the Alertmanager log on server.";
          };
        }
      ])
    ];
  }

  {
    name = "a notification that fails once, then goes out, does not alert";
    interval = "1m";
    input_series = [
      {
        series = ''alertmanager_notifications_failed_total{instance="server", job="alertmanager", integration="webhook", reason="serverError"}'';
        values = "0x14 1x40";
      }
    ];
    alert_rule_test = [ (noAlert "AlertDeliveryFailing" "31m") ];
  }
]

# "server" is always-on, "laptop" is not.
let
  minutes = count: "${toString count}m";

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
      description = "cloudflared on server has no connection to Cloudflare, so the public names it serves don't answer; see `systemctl status 'cloudflared-tunnel-*'` there.";
    };
  };
in
[
  {
    name = "a server whose node_exporter stops answering is down after 5 minutes, a laptop never is";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="node"}'';
        values = "1x10 0x30";
      }
      {
        series = ''up{instance="laptop", job="node"}'';
        values = "1x10 0x30";
      }
    ];
    alert_rule_test = [
      (noAlert "HostDown" (minutes 15))
      (firing "HostDown" (minutes 17) [ serverDown ])
      (firing "HostDown" (minutes 40) [ serverDown ])
    ];
  }

  {
    name = "a server missing a few scrapes is not down";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="node"}'';
        values = "1x10 0 1x10 0x3 1x10";
      }
    ];
    alert_rule_test = map (time: noAlert "HostDown" (minutes time)) [
      11
      15
      25
      30
    ];
  }

  {
    name = "a public name that stops answering alerts after 5 minutes, whatever serves it; one failed request does not";
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
      {
        series = ''probe_success{job="probe", instance="server", name="blip.example.com"}'';
        values = "1x5 0 1x20";
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
            description = "Requests to ${name}, which ${instance} serves, have failed for 5 minutes; see Public names on the fleet page.";
          };
        };
      in
      [
        (noAlert "PublicNameDown" (minutes 10))
        (firing "PublicNameDown" (minutes 12) [
          (down "app.example.com" "server")
          (down "go.example.com" "cloudflare")
        ])
      ];
  }

  {
    name = "a prober that can't be scraped is one missing exporter, not one for each of its probes";
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
      (firing "ExporterDown" (minutes 20) [
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
      (noAlert "TunnelDown" (minutes 10))
      (firing "TunnelDown" (minutes 12) [ tunnelDown ])
    ];
  }

  {
    name = "a tunnel whose cloudflared stops is down too, and is not a missing exporter";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="cloudflared"}'';
        values = "1x5 0x30";
      }
    ];
    alert_rule_test = [
      (firing "TunnelDown" (minutes 12) [ tunnelDown ])
      (noAlert "ExporterDown" (minutes 30))
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
            description = "It expires in 13d 22h 0m 0s, and the machine then leaves the tailnet; sign it in again, or turn off key expiry for it in the admin console.";
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
      (noAlert "SystemdUnitFailed" (minutes 9))
      (firing "SystemdUnitFailed" (minutes 11) [
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
    name = "a disk filling within a day warns on servers only, and its read-only bind mount stays quiet";
    interval = "5m";
    input_series =
      let
        # 9% free of 100 GB, losing 600 MB an hour.
        mount = instance: mountpoint: readonly: [
          {
            series = ''node_filesystem_avail_bytes{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "9000000000-50000000x60";
          }
          {
            series = ''node_filesystem_size_bytes{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "100000000000x60";
          }
          {
            series = ''node_filesystem_readonly{instance="${instance}", device="/dev/sda1", fstype="ext4", mountpoint="${mountpoint}"}'';
            values = "${readonly}x60";
          }
        ];
      in
      mount "server" "/" "0" ++ mount "server" "/nix/store" "1" ++ mount "laptop" "/" "0";
    alert_rule_test = [
      (noAlert "FilesystemFillingUp" (minutes 60))
      (firing "FilesystemFillingUp" "3h" [
        {
          exp_labels = {
            instance = "server";
            device = "/dev/sda1";
            fstype = "ext4";
            mountpoint = "/";
            severity = "warning";
          };
          exp_annotations = {
            summary = "/ on server fills up within a day";
            description = "7.2% free, shrinking at the last day's rate.";
          };
        }
      ])
      (noAlert "FilesystemAlmostFull" "3h")
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
        series = ''node_filesystem_readonly{instance="server", device="/dev/sda1", fstype="ext4", mountpoint="/nix/store"}'';
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
      (firing "FilesystemReadOnly" (minutes 6) [
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
    name = "a server's backup warns once its newest snapshot is a day and a half old and is critical after three days";
    interval = "1h";
    input_series = [
      {
        series = ''restic_snapshot_timestamp_seconds{instance="server", backup="state"}'';
        values = "0x80";
      }
      {
        series = ''restic_snapshot_timestamp_seconds{instance="server", backup="fresh"}'';
        values = "0+3600x80";
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
    name = "a drive warns while its bad-sector count grows or SMART fails it, not for a count that stays put";
    interval = "1h";
    input_series = [
      {
        series = ''smartctl_device_attribute{instance="server", device="sdd", attribute_name="Offline_Uncorrectable", attribute_value_type="raw"}'';
        values = "30x24 32x30";
      }
      {
        series = ''smartctl_device_attribute{instance="server", device="sdb", attribute_name="Current_Pending_Sector", attribute_value_type="raw"}'';
        values = "5x54";
      }
      {
        series = ''smartctl_device_smart_status{instance="server", device="nvme0"}'';
        values = "1x40 0x14";
      }
    ];
    alert_rule_test = [
      (noAlert "DriveDegrading" "20h")
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
            description = "Its bad-sector counts grew in the last day, or SMART says it failed; see its row under Drives on the fleet page, and `smartctl -a` on server.";
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
            description = "Its bad-sector counts grew in the last day, or SMART says it failed; see its row under Drives on the fleet page, and `smartctl -a` on server.";
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
      (firing "HardwareTooHot" (minutes 11) [
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
      (noAlert "AlertDeliveryFailing" (minutes 29))
      (firing "AlertDeliveryFailing" (minutes 31) [
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
    alert_rule_test = map (time: noAlert "AlertDeliveryFailing" (minutes time)) [
      20
      31
      50
    ];
  }
]

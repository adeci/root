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
      severity = "critical";
    };
    exp_annotations = {
      summary = "server is down";
      description = "No metrics from server for 10 minutes.";
    };
  };
in
[
  {
    name = "a server that stops reporting is down after 10 minutes, a laptop never is";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="integrations/unix"}'';
        values = "1x30";
      }
      {
        series = ''up{instance="laptop", job="integrations/unix"}'';
        values = "1x10";
      }
    ];
    alert_rule_test = [
      (noAlert "HostDown" (minutes 39))
      (firing "HostDown" (minutes 41) [ serverDown ])
      (firing "HostDown" "3h" [ serverDown ])
    ];
  }

  {
    name = "a server missing a few minutes of metrics is not down";
    interval = "1m";
    input_series = [
      {
        series = ''up{instance="server", job="integrations/unix"}'';
        values = "1x20 _x8 1x20";
      }
    ];
    alert_rule_test = map (time: noAlert "HostDown" (minutes time)) [
      25
      29
      35
      45
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
    name = "backups that have not run for a day and a half are stale";
    interval = "5m";
    input_series = [
      {
        series = ''node_systemd_timer_last_trigger_seconds{instance="server", name="restic-backups-state.timer"}'';
        values = "3600x480";
      }
      {
        series = ''node_systemd_timer_last_trigger_seconds{instance="server", name="restic-backups-fresh.timer"}'';
        values = "0+300x480";
      }
    ];
    alert_rule_test = [
      (noAlert "BackupStale" "37h")
      (firing "BackupStale" "38h" [
        {
          exp_labels = {
            instance = "server";
            name = "restic-backups-state.timer";
            severity = "warning";
          };
          exp_annotations = {
            summary = "Backups on server are stale";
            description = "restic-backups-state.timer last fired 1d 13h 0m 0s ago.";
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
]

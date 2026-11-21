# LaptopBackupStale over weeks of use; "laptop" is not always-on.
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

  # LaptopBackupStale on "laptop", with how long it has been on since its newest snapshot.
  laptopStale = severity: on: {
    exp_labels = {
      instance = "laptop";
      backup = "state";
      inherit severity;
    };
    exp_annotations = {
      summary =
        if severity == "warning" then
          "laptop has gone days of use without a backup"
        else
          "laptop has gone a week of use without a backup";
      description = "On for ${on} of the last 30 days since the newest snapshot in its state repository. Backups need AC power, an unmetered network and a reachable repository; `journalctl -u restic-state-when-due` on laptop says which was missing.";
    };
  };
in
[
  {
    name = "a laptop's backup warns after 3 days on and is critical after 7; time off doesn't count";
    interval = "5m";
    input_series = [
      {
        series = ''restic_snapshot_timestamp_seconds{instance="laptop", backup="state"}'';
        # On for two days, off for five, then on again.
        values = "0x575 _x1440 0x2000";
      }
    ];
    alert_rule_test = [
      (noAlert "LaptopBackupStale" "191h")
      (firing "LaptopBackupStale" "193h" [ (laptopStale "warning" "3d 1h 30m 0s") ])
      (firing "LaptopBackupStale" "290h" [
        (laptopStale "warning" "7d 2h 30m 0s")
        (laptopStale "critical" "7d 2h 30m 0s")
      ])
    ];
  }

  {
    name = "a laptop counts again from each new snapshot";
    interval = "5m";
    input_series = [
      {
        series = ''restic_snapshot_timestamp_seconds{instance="laptop", backup="state"}'';
        # The next snapshot comes after 70 hours on.
        values = "0x839 252000x900";
      }
    ];
    alert_rule_test = [ (noAlert "LaptopBackupStale" "73h") ];
  }

  {
    name = "a laptop on 1.5 hours a day warns after a day on once its snapshot is older than 30 days";
    interval = "30m";
    input_series = [
      {
        series = ''restic_snapshot_timestamp_seconds{instance="laptop", backup="state"}'';
        # A snapshot four months old, and three half hours on at the start of each day.
        values = builtins.concatStringsSep " " (builtins.genList (_: "-10000000x2 _x45") 20);
      }
    ];
    alert_rule_test = [
      (noAlert "LaptopBackupStale" "337h")
      (firing "LaptopBackupStale" "385h" [ (laptopStale "warning" "1d 1h 30m 0s") ])
    ];
  }

  {
    name = "a laptop that never backed up (snapshot time 0) warns after a day on";
    interval = "30m";
    input_series = [
      {
        series = ''restic_snapshot_timestamp_seconds{instance="laptop", backup="state"}'';
        # New a month in, and never backed up.
        values = "_x1488 0x200";
      }
    ];
    alert_rule_test = [
      (noAlert "LaptopBackupStale" "767h")
      (firing "LaptopBackupStale" "769h" [ (laptopStale "warning" "1d 1h 30m 0s") ])
    ];
  }
]

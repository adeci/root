# Series values are a minute apart, promtool's default.
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

  xidError = {
    exp_labels = {
      instance = "leviathan";
      job = "dcgm";
      gpu = "0";
      severity = "warning";
    };
    exp_annotations = {
      summary = "GPU 0 on leviathan hit Xid error 79";
      description = "Look up the Xid in NVIDIA's list and check `dmesg`; 48, 63, 64, 74 and 79 point at failing hardware.";
    };
  };
in
{
  inherit (import ./monitoring.nix) rules;

  tests = [
    {
      name = "a new Xid error alerts at once and for 15 minutes, the code of an old one does not";
      input_series = [
        {
          series = ''DCGM_FI_DEV_XID_ERRORS{instance="leviathan", job="dcgm", gpu="0"}'';
          values = "0x9 79x30";
        }
      ];
      alert_rule_test = [
        (firing "GpuXidError" "10m" [ xidError ])
        (firing "GpuXidError" "23m" [ xidError ])
        (noAlert "GpuXidError" "25m")
      ];
    }

    {
      name = "a GPU over 85°C for 10 minutes is too hot, one at 80°C is not";
      input_series = [
        {
          series = ''DCGM_FI_DEV_GPU_TEMP{instance="leviathan", job="dcgm", gpu="0"}'';
          values = "90x20";
        }
        {
          series = ''DCGM_FI_DEV_GPU_TEMP{instance="leviathan", job="dcgm", gpu="1"}'';
          values = "80x20";
        }
      ];
      alert_rule_test = [
        (noAlert "GpuTooHot" "9m")
        (firing "GpuTooHot" "11m" [
          {
            exp_labels = {
              instance = "leviathan";
              job = "dcgm";
              gpu = "0";
              severity = "warning";
            };
            exp_annotations = {
              summary = "GPU 0 on leviathan is running hot";
              description = "It reads 90°C; check the chassis fans and airflow.";
            };
          }
        ])
      ];
    }
  ];
}

# Monitoring agent settings for leviathan: alerts and a dashboard for its NVIDIA GPUs.
let
  ui = import ../../clan-services/monitoring/dashboards/lib.nix;

  gpus = ''instance="leviathan", job="dcgm"'';
  perGpu = metric: ui.target "A" "${metric}{${gpus}}" "GPU {{gpu}}";
in
{
  rules = [
    {
      alert = "GpuXidError";
      # DCGM reports the code of the last Xid error, so a change means a new fault.
      expr = ''
        max_over_time(DCGM_FI_DEV_XID_ERRORS{${gpus}}[15m]) != 0
        and changes(DCGM_FI_DEV_XID_ERRORS{${gpus}}[15m]) > 0
      '';
      labels.severity = "warning";
      annotations = {
        summary = "GPU {{ $labels.gpu }} on leviathan hit Xid error {{ $value }}";
        description = "Look up the Xid in NVIDIA's list and check `dmesg`; 48, 63, 64, 74 and 79 point at failing hardware.";
      };
    }
    {
      alert = "GpuTooHot";
      expr = "DCGM_FI_DEV_GPU_TEMP{${gpus}} > 85";
      for = "10m";
      labels.severity = "warning";
      annotations = {
        summary = "GPU {{ $labels.gpu }} on leviathan is running hot";
        description = "It reads {{ $value }}°C; check the chassis fans and airflow.";
      };
    }
  ];

  dashboards.gpus = ui.dashboard {
    uid = "leviathan-gpus";
    title = "GPUs / leviathan";
    panels = [
      (ui.timeseries {
        id = 1;
        title = "Utilization";
        x = 0;
        y = 0;
        w = 12;
        h = 8;
        unit = "percent";
        threshold = ui.thresholds.neutral;
        targets = [ (perGpu "DCGM_FI_DEV_GPU_UTIL") ];
      })
      (ui.timeseries {
        id = 2;
        title = "Memory used";
        x = 12;
        y = 0;
        w = 12;
        h = 8;
        unit = "percent";
        targets = [
          (ui.target "A"
            "100 * DCGM_FI_DEV_FB_USED{${gpus}} / (DCGM_FI_DEV_FB_USED{${gpus}} + DCGM_FI_DEV_FB_FREE{${gpus}})"
            "GPU {{gpu}}"
          )
        ];
      })
      (ui.timeseries {
        id = 3;
        title = "Temperature";
        x = 0;
        y = 8;
        w = 12;
        h = 8;
        unit = "celsius";
        threshold = ui.thresholds.temperatureC;
        targets = [
          (perGpu "DCGM_FI_DEV_GPU_TEMP")
          (ui.target "B" "DCGM_FI_DEV_MEMORY_TEMP{${gpus}}" "GPU {{gpu}} memory")
        ];
      })
      (ui.timeseries {
        id = 4;
        title = "Power";
        x = 12;
        y = 8;
        w = 12;
        h = 8;
        unit = "watt";
        threshold = ui.thresholds.neutral;
        targets = [ (perGpu "DCGM_FI_DEV_POWER_USAGE") ];
      })
      (ui.stat {
        id = 5;
        title = "Last Xid error";
        x = 0;
        y = 16;
        w = 6;
        h = 4;
        expr = "max(DCGM_FI_DEV_XID_ERRORS{${gpus}})";
      })
      (ui.stat {
        id = 6;
        title = "PCIe replays";
        x = 6;
        y = 16;
        w = 6;
        h = 4;
        expr = "sum(increase(DCGM_FI_DEV_PCIE_REPLAY_COUNTER{${gpus}}[$__range]))";
      })
    ];
  };
}

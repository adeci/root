# Monitoring agent settings: GPU alerts and dashboard.
let
  ui = import ../../clan-services/monitoring/dashboards/lib.nix;

  gpus = ''instance="leviathan", job="dcgm"'';
  perGpu = metric: ui.target "${metric}{${gpus}}" "GPU {{gpu}}";
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
        title = "Utilization";
        w = 12;
        h = 8;
        unit = "percent";
        threshold = ui.thresholds.neutral;
        targets = [ (perGpu "DCGM_FI_DEV_GPU_UTIL") ];
      })
      (ui.timeseries {
        title = "Memory used";
        w = 12;
        h = 8;
        unit = "percent";
        targets = [
          (ui.target "100 * DCGM_FI_DEV_FB_USED{${gpus}} / (DCGM_FI_DEV_FB_USED{${gpus}} + DCGM_FI_DEV_FB_FREE{${gpus}})" "GPU {{gpu}}")
        ];
      })
      (ui.timeseries {
        title = "Temperature";
        w = 12;
        h = 8;
        unit = "celsius";
        threshold = ui.thresholds.temperatureC;
        targets = [
          (perGpu "DCGM_FI_DEV_GPU_TEMP")
          (ui.target "DCGM_FI_DEV_MEMORY_TEMP{${gpus}}" "GPU {{gpu}} memory")
        ];
      })
      (ui.timeseries {
        title = "Power";
        w = 12;
        h = 8;
        unit = "watt";
        threshold = ui.thresholds.neutral;
        targets = [ (perGpu "DCGM_FI_DEV_POWER_USAGE") ];
      })
      (ui.stat {
        title = "Last Xid error";
        w = 6;
        h = 4;
        expr = "max(DCGM_FI_DEV_XID_ERRORS{${gpus}})";
      })
      (ui.stat {
        title = "PCIe replays";
        w = 6;
        h = 4;
        expr = "sum(increase(DCGM_FI_DEV_PCIE_REPLAY_COUNTER{${gpus}}[$__range]))";
      })
    ];
  };
}

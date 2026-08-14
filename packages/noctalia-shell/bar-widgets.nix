{
  compactSystemMonitor ? false,
}:
let
  systemMonitor = {
    id = "SystemMonitor";
    compactMode = compactSystemMonitor;
    showCpuUsage = true;
    showCpuTemp = false;
    showGpuTemp = false;
    showGpuUsage = true;
    showMemoryUsage = true;
    showMemoryAsPercent = true;
    showNetworkStats = true;
    showDiskUsage = true;
    showDiskUsageAsPercent = true;
    showDiskAvailable = false;
    useMonospaceFont = true;
    usePadding = true;
    diskPath = "/";
  };
in
{
  left = [
    { id = "Launcher"; }
    {
      id = "Clock";
      formatHorizontal = "h:mm AP";
    }
    systemMonitor
    { id = "ActiveWindow"; }
    { id = "MediaMini"; }
  ];
  center = [
    { id = "Workspace"; }
  ];
  right = [
    { id = "Tray"; }
    { id = "NotificationHistory"; }
    { id = "plugin:niri-display"; }
    { id = "plugin:voxtype"; }
    { id = "plugin:mullvad"; }
    { id = "plugin:tailscale"; }
    { id = "Network"; }
    { id = "Battery"; }
    { id = "Volume"; }
    { id = "Brightness"; }
    { id = "ControlCenter"; }
  ];
}

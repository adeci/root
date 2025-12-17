{
  layer = "top";
  position = "top";
  height = 20;
  spacing = 0;

  modules-left = [ "niri/workspaces" ];

  modules-right = [
    "network"
    "bluetooth"
    "custom/cpu"
    "custom/gpu"
    "memory"
    "disk"
    "backlight"
    "pulseaudio"
    "custom/battery"
    "clock"
  ];

  "niri/workspaces" = {
    format = "{index}";
    # niri has dynamic workspaces - no persistent-workspaces like sway
  };

  network = {
    interface = "wlp1s0";
    format = "W ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
    format-wifi = "W ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
    format-ethernet = "W ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
    format-linked = "W ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
    format-disconnected = "W ↓ ----/s ↑ ----/s";
    format-disabled = "W ↓ ----/s ↑ ----/s";
    tooltip = true;
    tooltip-format = "{essid} ({signalStrength}%) {ipaddr}";
    tooltip-format-wifi = "{essid} ({signalStrength}%) {ipaddr}";
    tooltip-format-ethernet = "{ifname} {ipaddr}";
    tooltip-format-disconnected = "Disconnected";
    tooltip-format-disabled = "Disabled";
    on-click = "nmgui";
    interval = 1;
  };

  "custom/cpu" = {
    exec = ''
      usage=$(top -bn2 -d0.05 | grep "Cpu(s)" | tail -1 | awk '{printf "%3.0f", 100-$8}')
      temp=$(awk '{printf "%3d", $1/1000}' /sys/devices/pci0000:00/0000:00:18.3/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
      if [ "$temp" -ge 80 ]; then
        printf "CPU %s%% <span color='#F7768E'>%s°C</span>" "$usage" "$temp"
      else
        printf "CPU %s%% %s°C" "$usage" "$temp"
      fi
    '';
    format = "{}";
    tooltip = false;
    interval = 1;
  };

  "custom/gpu" = {
    exec = ''
      usage=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1 || echo "0")
      temp=$(awk '{printf "%3d", $1/1000}' /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
      if [ "$temp" -ge 80 ]; then
        printf "GPU %3d%% <span color='#F7768E'>%s°C</span>" "$usage" "$temp"
      else
        printf "GPU %3d%% %s°C" "$usage" "$temp"
      fi
    '';
    format = "{}";
    tooltip = false;
    interval = 1;
  };

  memory = {
    format = "MEM {used:>4.1f}G/{total:>4.1f}G";
    tooltip = false;
    interval = 1;
  };

  disk = {
    format = "DSK {used}/{total}";
    path = "/";
    tooltip = false;
    interval = 30;
  };

  pulseaudio = {
    format = "VOL {volume:>3}%";
    format-muted = "VOL  MTD";
    tooltip = false;
    format-icons.default = [
      ""
      ""
      ""
    ];
    on-click = "pavucontrol";
  };

  clock = {
    interval = 1;
    format = "{:%I:%M:%S %p}";
    tooltip-format = "<tt><big>{:%B %Y}</big>\n{calendar}</tt>";
    calendar = {
      mode = "year";
      mode-mon-col = 3;
      weeks-pos = "";
      on-scroll = 0;
      format = {
        months = "<span color='#ffffff'><b>{}</b></span>";
        days = "<span color='#888888'>{}</span>";
        weeks = "<span color='#666666'><b>W{}</b></span>";
        weekdays = "<span color='#aaaaaa'><b>{}</b></span>";
        today = "<span color='#000000' background='#ffffff'><b>{}</b></span>";
      };
    };
  };

  "custom/battery" = {
    exec = ''
      bat=$(ls -d /sys/class/power_supply/BAT* /sys/class/power_supply/BATT 2>/dev/null | head -1)
      cap=$(cat "$bat/capacity" 2>/dev/null)
      status=$(cat "$bat/status" 2>/dev/null)
      if [ -f "$bat/charge_now" ]; then
        mah=$(awk '{printf "%d", $1/1000}' "$bat/charge_now")
      elif [ -f "$bat/energy_now" ] && [ -f "$bat/voltage_now" ]; then
        energy=$(cat "$bat/energy_now")
        voltage=$(cat "$bat/voltage_now")
        mah=$(awk "BEGIN {printf \"%d\", ($energy / $voltage) * 1000}")
      else
        mah="?"
      fi
      if [ "$status" = "Charging" ]; then
        printf "<span color='#41A6B5'>BAT</span> %3d%% %5dmAh" "$cap" "$mah"
      elif [ "$cap" -le 10 ]; then
        printf "<span color='#F7768E'>BAT</span> %3d%% %5dmAh" "$cap" "$mah"
      elif [ "$cap" -le 20 ]; then
        printf "<span color='#E0AF68'>BAT</span> %3d%% %5dmAh" "$cap" "$mah"
      else
        printf "BAT %3d%% %5dmAh" "$cap" "$mah"
      fi
    '';
    format = "{}";
    tooltip = false;
    interval = 1;
  };

  backlight = {
    format = "BRT {percent:>3}%";
    tooltip = false;
  };

  bluetooth = {
    format = "BLU {status}";
    format-on = "BLU ON";
    format-off = "BLU OFF";
    format-connected = "BLU ON";
    format-disabled = "BLU OFF";
    tooltip = false;
    on-click = "blueman-manager";
  };
}

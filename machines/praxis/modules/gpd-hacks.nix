# GPD Pocket 4 hardware quirks and fixes.
# Consolidates audio DSP, suspend fixes, and touchscreen workarounds.
{ pkgs, ... }:
{
  # Fix USB keyboard (258a:000c) blocking suspend
  # Keep keyboard always-on but disable wakeup
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="258a", ATTRS{idProduct}=="000c", ATTR{power/wakeup}="disabled", ATTR{power/control}="on"
  '';

  # Disable XHC0 USB controller wakeup to prevent phantom wakes from suspend
  systemd.services.disable-usb-wakeup = {
    description = "Disable XHC0 USB controller wakeup";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo XHC0 > /proc/acpi/wakeup'";
      RemainAfterExit = true;
    };
  };

  # Alt layer bindings (keyd uses [alt] layer, not A- prefix)
  services.keyd.keyboards.default.settings.alt = {
    # Fix touchscreen (keyd runs as root, no sudo needed)
    equal = "command(${pkgs.systemd}/bin/systemctl start fix-touchscreen)";
    # Media controls — mirrors Fn+volume key positions
    leftbrace = "previoussong";
    rightbrace = "playpause";
    backslash = "nextsong";
  };

  # The GPD Pocket 4 touchscreen (NVTK0603) often fails to reinitialize
  # properly after suspend, coming back as PROP=2 (touchpad) instead of
  # PROP=1 (touchscreen). Cycling the i2c_hid_acpi module fixes it.
  # Also bound to Alt+= via keyd for manual trigger.
  systemd.services.fix-touchscreen = {
    description = "Reload i2c_hid_acpi to fix touchscreen after suspend";
    after = [
      "systemd-suspend.service"
      "systemd-hibernate.service"
    ];
    wantedBy = [
      "suspend.target"
      "hibernate.target"
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "fix-touchscreen" ''
        modprobe=${pkgs.kmod}/bin/modprobe
        grep=${pkgs.gnugrep}/bin/grep

        for attempt in 1 2; do
          $modprobe -r i2c_hid_acpi 2>/dev/null || true
          sleep 2
          $modprobe i2c_hid_acpi
          sleep 2

          if $grep -A8 'NVTK0603' /proc/bus/input/devices | $grep -q 'PROP=1'; then
            echo "Touchscreen restored (attempt $attempt)"
            exit 0
          fi
        done

        echo "Touchscreen not restored after 2 attempts" >&2
        exit 1
      '';
    };
  };
}

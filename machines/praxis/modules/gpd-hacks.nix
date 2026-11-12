{ pkgs, ... }:
{
  # The USB keyboard (258a:000c) otherwise blocks suspend.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="258a", ATTRS{idProduct}=="000c", ATTR{power/wakeup}="disabled", ATTR{power/control}="on"
  '';

  # XHC0 causes phantom wakes from suspend.
  systemd.services.disable-usb-wakeup = {
    description = "Disable XHC0 USB controller wakeup";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # Writing the name toggles, so a restart (e.g. a switch after a bash bump) would re-enable it.
      ExecStart = pkgs.writeShellScript "disable-xhc0-wakeup" ''
        if ${pkgs.gnugrep}/bin/grep -q '^XHC0\s.*\*enabled' /proc/acpi/wakeup; then
          echo XHC0 > /proc/acpi/wakeup
        fi
      '';
      RemainAfterExit = true;
    };
  };

  # keyd binds Alt combos through the [alt] layer, not an A- prefix.
  services.keyd.keyboards.default.settings.alt = {
    # keyd runs as root, so no sudo is needed.
    equal = "command(${pkgs.systemd}/bin/systemctl start fix-touchscreen)";
    # Same positions as the Fn+volume keys.
    leftbrace = "previoussong";
    rightbrace = "playpause";
    backslash = "nextsong";
  };

  # The NVTK0603 touchscreen often resumes as PROP=2 (touchpad), not PROP=1; reloading i2c_hid_acpi fixes it.
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

# GPD Pocket 4 hardware quirks and fixes.
# Consolidates audio DSP, suspend fixes, and touchscreen workarounds.
{ pkgs, ... }:
{
  imports = [ ./audio-dsp.nix ];

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

  # Reload i2c_hid_acpi module to fix intermittent touchscreen breakage
  # after suspension. Runs automatically on resume; can also be triggered
  # manually with: systemctl start fix-touchscreen
  systemd.services.fix-touchscreen =
    let
      fix-touchscreen = pkgs.writeShellScript "fix-touchscreen" ''
        export PATH=${
          pkgs.lib.makeBinPath [
            pkgs.kmod
            pkgs.systemd
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
          ]
        }

        for attempt in 1 2 3; do
          modprobe -r i2c_hid_acpi 2>/dev/null || true
          udevadm settle --timeout=5
          sleep 1
          modprobe i2c_hid_acpi
          udevadm settle --timeout=5

          # Check if a touchscreen input device appeared under the driver
          if find /sys/bus/i2c/drivers/i2c_hid_acpi/ -path '*/input/input*/name' 2>/dev/null \
               | xargs -r grep -qi touch; then
            echo "Touchscreen restored on attempt $attempt"
            exit 0
          fi

          echo "Attempt $attempt: touchscreen not detected, retrying..."
          sleep 1
        done

        echo "Warning: touchscreen not detected after 3 attempts"
        exit 1
      '';
    in
    {
      description = "Reload i2c_hid_acpi module to fix touchscreen";
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
        ExecStart = fix-touchscreen;
      };
    };
}

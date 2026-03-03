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

  # Manually reload i2c_hid_acpi module to fix intermittent touchscreen
  # breakage after suspension. Run with: systemctl start fix-touchscreen
  systemd.services.fix-touchscreen = {
    description = "Reload i2c_hid_acpi module to fix touchscreen";
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.kmod}/bin/modprobe -r i2c_hid_acpi";
      ExecStart = "${pkgs.kmod}/bin/modprobe i2c_hid_acpi";
    };
  };
}

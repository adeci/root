{ lib, pkgs, ... }:
let
  disableXhc0Wakeup = pkgs.writeShellApplication {
    name = "disable-xhc0-wakeup";
    runtimeInputs = [ pkgs.gnugrep ];
    text = builtins.readFile ./disable-xhc0-wakeup.sh;
  };

  fixTouchscreen = pkgs.writeShellApplication {
    name = "fix-touchscreen";
    runtimeInputs = [
      pkgs.gnugrep
      pkgs.kmod
    ];
    text = builtins.readFile ./fix-touchscreen.sh;
  };
in
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
      ExecStart = lib.getExe disableXhc0Wakeup;
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
      ExecStart = lib.getExe fixTouchscreen;
    };
  };
}

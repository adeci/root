{
  nixos =
    { config, pkgs, ... }:
    {
      environment.systemPackages = [
        pkgs.cheese
        pkgs.powertop
        config.boot.kernelPackages.turbostat
      ];
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      services.blueman.enable = true;
      # For libinput's udev rules, which niri uses too; the rest is X11-only.
      services.libinput.enable = true;
      powerManagement.enable = true;
      services.upower.enable = true;
      services.power-profiles-daemon.enable = true;
      services.logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchDocked = "suspend";
        HandleLidSwitchExternalPower = "suspend";
        HandlePowerKey = "poweroff";
      };
    };

  darwin = {
    system.defaults.trackpad.Clicking = true;

    # Only closing the lid sleeps the Mac; idle just turns the display off.
    system.activationScripts.postActivation.text = ''
      /usr/bin/pmset -a sleep 0
    '';
  };
}

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
      # Installs libinput's udev rules, which niri's libinput reads too; the option's other settings are for X11.
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

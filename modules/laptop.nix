{
  nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.cheese ];
      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };
      services.blueman.enable = true;
      services.libinput = {
        enable = true;
        touchpad = {
          tapping = true;
          disableWhileTyping = true;
          naturalScrolling = true;
          tappingDragLock = false;
        };
      };
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

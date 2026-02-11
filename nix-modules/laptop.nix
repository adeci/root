{
  pkgs,
  ...
}:
{
  environment.systemPackages = [
    pkgs.cheese
  ];

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

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend";
    HandleLidSwitchDocked = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey = "poweroff";
  };

  services.xserver.xkb.layout = "us";
}

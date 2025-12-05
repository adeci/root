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

  services.xserver.xkb.layout = "us";
}

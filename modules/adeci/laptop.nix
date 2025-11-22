_: {
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
    };
  };

  services.xserver.xkb.layout = "us";

  powerManagement.enable = true;
}

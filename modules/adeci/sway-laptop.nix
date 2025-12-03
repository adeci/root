{
  inputs,
  pkgs,
  ...
}:
let
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./sway-base.nix ];

  environment.systemPackages = [
    dotpkgs.waybar-laptop
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

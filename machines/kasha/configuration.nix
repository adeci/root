{
  inputs,
  pkgs,
  self,
  ...
}:
{

  imports = with self.modules.nixos; [
    self.users.alex.nixosModule
    self.users.natalya.nixosModule

    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-amd

    base
    zsh
    auto-pressure-gc
    zram
    auto-timezone
    gnome
    amd-gpu
    printing
  ];

  system.primaryUser = self.users.alex.username;

  wrappers.btop.settings.cpu_sensor = "k10temp/Tctl";

  boot.loader = {
    timeout = 0;
    grub = {
      timeoutStyle = "hidden";
    };
  };

  environment.systemPackages = with pkgs; [
    firefox
  ];

  environment.gnome.excludePackages = with pkgs; [
    epiphany
  ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Fix mic mute LED being always on
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{trigger}="none", ATTR{brightness}="0"
  '';
}

{
  inputs,
  pkgs,
  self,
  ...
}:
{

  imports = [
    self.users.alex.nixosModule
    self.users.natalya.nixosModule

    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-amd

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/gnome.nix
    ../../modules/nixos/amd-gpu.nix
    ../../modules/nixos/printing.nix
  ];

  boot.loader = {
    timeout = 0;
    grub = {
      timeoutStyle = "hidden";
    };
  };

  environment.systemPackages = with pkgs; [
    firefox
    rustdesk
  ];

  environment.gnome.excludePackages = with pkgs; [
    epiphany
  ];

  # Enable fractional scaling in GNOME
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer']
  '';

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Fix mic mute LED being always on
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{trigger}="none", ATTR{brightness}="0"
  '';

  nix.settings.trusted-users = [
    "root"
    self.users.alex.username
  ];

}

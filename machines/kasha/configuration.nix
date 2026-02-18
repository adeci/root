{
  inputs,
  pkgs,
  config,
  ...
}:
{

  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-amd

    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    shell.enable = true;
    gnome.enable = true;
    amd-gpu.enable = true;
    printing.enable = true;
  };

  networking = {
    networkmanager.enable = true;
    hostName = "kasha";
  };

  time.timeZone = "Asia/Almaty";

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
    "@wheel"
    config.adeci.primaryUser
  ];

}

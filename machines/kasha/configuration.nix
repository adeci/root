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
    printing.enable = true;
    home-manager.enable = true;
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

  # btop needs rocm-smi and libdrm in ld path for gpu monitoring
  environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.rocmPackages.rocm-smi}/lib:${pkgs.libdrm}/lib";

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # Fix mic mute LED being always on
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="platform::micmute", ATTR{trigger}="none", ATTR{brightness}="0"
  '';

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.stateVersion = config.system.stateVersion;
  };

  nix.settings = {
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB
    trusted-users = [
      "root"
      "@wheel"
      "alex"
    ];
  };

}

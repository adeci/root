{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [
    inputs.jovian.nixosModules.default
  ];

  # Steam Deck hardware support (kernel, fan control, firmware, audio DSP, controller)
  jovian.devices.steamdeck.enable = true;

  # Gaming Mode via gamescope session
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = config.adeci.primaryUser;
    desktopSession = "niri";
  };

  # Decky Loader plugin framework for Gaming Mode
  jovian.decky-loader = {
    enable = true;
    user = config.adeci.primaryUser;
  };

  # X11 input translation for Wayland desktop mode
  programs.steam.extest.enable = true;

  # Enhanced game compatibility
  programs.steam.extraCompatPackages = with pkgs; [
    proton-ge-bin
  ];

  # Performance overlay
  environment.systemPackages = with pkgs; [
    mangohud
  ];

  # Silent boot for clean splash → Gaming Mode transition
  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [ "quiet" ];

  # NetworkManager required for Steam network management
  networking.networkmanager.enable = true;
}

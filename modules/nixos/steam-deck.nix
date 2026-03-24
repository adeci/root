{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.jovian.nixosModules.default
  ];

  # Steam Deck hardware support (kernel, fan control, firmware, audio DSP, controller)
  jovian.devices.steamdeck.enable = true;
  jovian.devices.steamdeck.autoUpdate = true;

  # Gaming Mode via gamescope session
  jovian.steam = {
    enable = true;
    autoStart = true;
    user = config.adeci.primaryUser;
    desktopSession = "niri";
    environment = {
      # nixpkgs sets this on the Steam wrapper, but Gaming Mode bypasses it
      STEAM_EXTRA_COMPAT_TOOLS_PATHS =
        lib.makeSearchPathOutput "steamcompattool" ""
          config.programs.steam.extraCompatPackages;
    };
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
  boot.loader.timeout = 1;
  boot.loader.grub.timeoutStyle = "hidden";

  # NetworkManager required for Steam network management
  networking.networkmanager.enable = true;
}

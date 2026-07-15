{
  config,
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  deckyLoader = (pkgs.decky-loader.override { pnpm_9 = pkgs.pnpm_10; }).overridePythonAttrs (old: {
    # Jovian still pins insecure pnpm 9. Drop this when it moves to pnpm 10.
    pnpmDeps = old.pnpmDeps.overrideAttrs (_: {
      outputHash = "sha256-X1L8JYG5hgYMmfg0aa8XhkRU6/oFrYTPiXDIyq77puE=";
    });
  });
in
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
    user = self.users.alex.username;
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
    package = deckyLoader;
    user = self.users.alex.username;
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

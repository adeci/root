{
  nixos =
    {
      config,
      inputs,
      lib,
      pkgs,
      self,
      ...
    }:
    {
      imports = [
        inputs.jovian.nixosModules.default
        self.modules.nixos.niri
        self.modules.nixos.primary-user
      ];

      jovian.devices.steamdeck.enable = true;
      jovian.devices.steamdeck.autoUpdate = true;

      jovian.steam = {
        enable = true;
        autoStart = true;
        user = config.system.primaryUser;
        desktopSession = "niri";
        environment = {
          # nixpkgs sets this on the Steam wrapper, but Gaming Mode bypasses it
          STEAM_EXTRA_COMPAT_TOOLS_PATHS =
            lib.makeSearchPathOutput "steamcompattool" ""
              config.programs.steam.extraCompatPackages;
        };
      };

      jovian.decky-loader = {
        enable = true;
        user = config.system.primaryUser;
      };

      # X11 input translation for Wayland desktop mode
      programs.steam.extest.enable = true;

      programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

      environment.systemPackages = [ pkgs.mangohud ];

      boot.consoleLogLevel = 0;
      boot.kernelParams = [ "quiet" ];
      boot.loader.timeout = 1;
      boot.loader.grub.timeoutStyle = "hidden";

      # NetworkManager required for Steam network management
      networking.networkmanager.enable = true;
    };
}

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
      ];

      jovian.devices.steamdeck.enable = true;
      jovian.devices.steamdeck.autoUpdate = true;

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

      jovian.decky-loader = {
        enable = true;
        user = self.users.alex.username;
      };

      # X11 input translation for Wayland desktop mode
      programs.steam.extest.enable = true;

      programs.steam.extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];

      environment.systemPackages = with pkgs; [
        mangohud
      ];

      boot.consoleLogLevel = 0;
      boot.kernelParams = [ "quiet" ];
      boot.loader.timeout = 1;
      boot.loader.grub.timeoutStyle = "hidden";

      # NetworkManager required for Steam network management
      networking.networkmanager.enable = true;
    };
}

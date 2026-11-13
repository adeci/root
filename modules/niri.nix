{
  nixos =
    {
      config,
      pkgs,
      self,
      ...
    }:
    {
      imports = [
        self.modules.nixos.wrappers
        self.modules.nixos.noctalia
      ];

      programs.niri.enable = true;
      programs.niri.package = config.wrappers.niri.wrapper;

      wrappers.kitty.enable = true;
      wrappers.niri.terminal = config.wrappers.kitty.wrapper;
      fonts.packages = [ pkgs.nerd-fonts.caskaydia-mono ];

      environment.systemPackages = [
        pkgs.xwayland-satellite
        pkgs.wl-clipboard
        pkgs.wl-mirror
      ];
    };
}

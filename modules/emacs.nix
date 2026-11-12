{
  # zmx sessions keep shells alive across Emacs daemon restarts.
  nixos =
    {
      config,
      pkgs,
      self,
      ...
    }:
    {
      imports = [ self.modules.nixos.wrappers ];

      services.emacs = {
        enable = true;
        package = config.wrappers.emacs.wrapper;
        # Frames and in-Emacs terminals need the WAYLAND_DISPLAY and SHELL the graphical session imports into the user manager.
        startWithGraphical = true;
      };

      environment.systemPackages = [ pkgs.zmx ];
      fonts.packages = [ pkgs.nerd-fonts.caskaydia-mono ];
    };
}

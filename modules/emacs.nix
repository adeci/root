{
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
        # Needs WAYLAND_DISPLAY and SHELL from the graphical session.
        startWithGraphical = true;
      };

      # zmx sessions keep shells alive across Emacs daemon restarts.
      environment.systemPackages = [ pkgs.zmx ];
    };
}

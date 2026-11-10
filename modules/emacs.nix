{
  # zmx sessions keep shells alive across Emacs daemon restarts. The font comes
  # from the desktop feature.
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
        # The graphical session imports WAYLAND_DISPLAY and SHELL into the user
        # manager; frames and ghostel's shell need them.
        startWithGraphical = true;
      };

      environment.systemPackages = [ pkgs.zmx ];
    };
}

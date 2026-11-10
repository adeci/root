{
  # Full desktops bring their own polkit agent; niri doesn't.
  nixos =
    {
      config,
      pkgs,
      self,
      ...
    }:
    {
      imports = [ self.modules.nixos.wrappers ];

      programs.niri.enable = true;
      programs.niri.package = config.wrappers.niri.wrapper;

      environment.systemPackages = [
        pkgs.xwayland-satellite
        pkgs.wl-clipboard
        pkgs.wl-clip-persist
        pkgs.wl-mirror
        pkgs.playerctl
        pkgs.brightnessctl
      ];

      systemd.user.services.polkit-gnome = {
        description = "Polkit GNOME authentication agent";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        requisite = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
        };
      };
    };
}

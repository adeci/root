{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.adeci.niri;
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.adeci.niri.enable = lib.mkEnableOption "Niri compositor";
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      packages.kitty
      pkgs.nautilus
      pkgs.xwayland-satellite
      pkgs.libnotify
      pkgs.playerctl
      pkgs.pulseaudio
      pkgs.pavucontrol
      pkgs.wl-clipboard
      pkgs.wl-clip-persist
      pkgs.brightnessctl
      pkgs.phinger-cursors
      pkgs.adwaita-icon-theme
      pkgs.tokyonight-gtk-theme
      pkgs.glib
      pkgs.jq
      pkgs.xdg-utils
      pkgs.nmgui
    ];
    fonts.packages = with pkgs; [
      nerd-fonts.caskaydia-mono
      noto-fonts-color-emoji
    ];
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    programs.niri.enable = true;
    security.pam.services.login.enableGnomeKeyring = true;
    environment.sessionVariables = {
      XCURSOR_THEME = "phinger-cursors-dark";
      XCURSOR_SIZE = "24";
      GTK_THEME = "Tokyonight-Dark";
      QT_QPA_PLATFORMTHEME = "gtk3";
    };
    programs.dconf.profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            gtk-theme = "Tokyonight-Dark";
            color-scheme = "prefer-dark";
            cursor-theme = "phinger-cursors-dark";
            cursor-size = lib.gvariant.mkInt32 24;
          };
          "org/gnome/desktop/background" = {
            color-shading-type = "solid";
            picture-options = "zoom";
            prefer-dark-theme = true;
          };
        };
      }
    ];
    systemd.user.services.polkit-gnome = {
      description = "Polkit GNOME authentication agent";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      requisite = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
      };
      wantedBy = [ "niri.service" ];
    };
  };
}

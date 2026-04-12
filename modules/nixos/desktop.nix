# Full desktop: niri compositor, audio, fonts, and common tools.
{
  lib,
  self,
  pkgs,
  ...
}:
let
  wrapped = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./pipewire.nix
    ./librewolf.nix
  ];

  # Niri compositor with baked-in config
  programs.niri.enable = true;
  programs.niri.package = wrapped.niri;

  fonts.packages = with pkgs; [
    nerd-fonts.caskaydia-mono
    noto-fonts-color-emoji
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # GCR SSH agent can't handle FIDO2 keys — use the standard ssh-agent instead.
  # GNOME Keyring itself stays for secret storage (Electron apps, etc.)
  services.gnome.gcr-ssh-agent.enable = false;
  programs.ssh.startAgent = lib.mkDefault true;

  # Theme packages needed at the system level so the cursor/icons resolve
  # for portals, login greeters, and apps outside niri.
  # The niri wrapper carries identical settings for the standalone demo.
  environment.systemPackages = [
    pkgs.tokyonight-gtk-theme
    pkgs.papirus-icon-theme
    pkgs.phinger-cursors
    wrapped.kitty
    wrapped.noctalia-shell
    pkgs.nautilus
    pkgs.xwayland-satellite
    pkgs.libnotify
    pkgs.playerctl
    pkgs.pulseaudio
    pkgs.pavucontrol
    pkgs.easyeffects
    pkgs.wl-clipboard
    pkgs.wl-clip-persist
    pkgs.brightnessctl
    pkgs.jq
    pkgs.xdg-utils
    pkgs.nmgui
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = "phinger-cursors-dark";
    XCURSOR_SIZE = "24";
    GTK_THEME = "Tokyonight-Dark";
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  programs.dconf = {
    enable = lib.mkDefault true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            gtk-theme = "Tokyonight-Dark";
            icon-theme = "Papirus-Dark";
            color-scheme = "prefer-dark";
            cursor-theme = "phinger-cursors-dark";
            cursor-size = lib.gvariant.mkInt32 24;
          };
        };
      }
    ];
  };

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
    wantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.easyeffects = {
    description = "EasyEffects audio processing";
    partOf = [ "graphical-session.target" ];
    after = [
      "graphical-session.target"
      "pipewire.service"
    ];
    requisite = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.easyeffects}/bin/easyeffects --gapplication-service";
      Restart = "on-failure";
      RestartSec = 3;
    };
    wantedBy = [ "graphical-session.target" ];
  };
}

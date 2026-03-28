# Full desktop: niri compositor, audio, theming, fonts, and common tools.
{
  self,
  pkgs,
  ...
}:
let
  wrapped = self.packages.${pkgs.system};
in
{
  imports = [
    ./pipewire.nix
    ./gtk-theme.nix
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

  # Disable only the GCR SSH agent — it can't handle FIDO2 keys.
  # GNOME Keyring itself stays for secret storage (Electron apps, etc.)
  services.gnome.gcr-ssh-agent.enable = false;

  environment.systemPackages = [
    wrapped.librewolf
    pkgs.nautilus
    pkgs.xwayland-satellite
    pkgs.libnotify
    pkgs.playerctl
    pkgs.pulseaudio
    pkgs.pavucontrol
    pkgs.wl-clipboard
    pkgs.wl-clip-persist
    pkgs.brightnessctl
    pkgs.jq
    pkgs.xdg-utils
    pkgs.nmgui
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
    wantedBy = [ "graphical-session.target" ];
  };
}

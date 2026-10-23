# Full desktop: niri compositor, audio, fonts, and common tools.
{
  config,
  lib,
  self,
  pkgs,
  ...
}:
let
  wrapped = self.packages.${pkgs.stdenv.hostPlatform.system};
  machineKdl = config.thaw.apps.niri.files."machine.kdl" or null;
in
{
  imports = [
    ./easyeffects
    ./pipewire.nix
    ./handy.nix
    ./librewolf.nix
  ];

  # Desktop machines need interactive network management (WiFi, VPNs,
  # captive portals). Servers use clan's networkd default instead.
  networking.networkmanager.enable = true;
  networking.useNetworkd = false;

  programs.niri.enable = true;
  programs.niri.package = wrapped.niri;

  # Validate the shared config with this machine's file beside it, as niri sees them.
  system.checks = lib.optional (machineKdl != null) (
    pkgs.runCommand "niri-machine-config" { } ''
      cp ${../../packages/niri/config.kdl} config.kdl
      cp ${machineKdl} machine.kdl
      ${lib.getExe config.programs.niri.package} validate -c config.kdl
      touch $out
    ''
  );

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
  environment.systemPackages = [
    pkgs.adw-gtk3
    pkgs.papirus-icon-theme
    pkgs.phinger-cursors
    wrapped.kitty
    pkgs.nautilus
    pkgs.xwayland-satellite
    pkgs.libnotify
    pkgs.playerctl
    pkgs.pulseaudio
    pkgs.pavucontrol
    pkgs.wl-clipboard
    pkgs.wl-clip-persist
    pkgs.wl-mirror
    pkgs.brightnessctl
    pkgs.jq
    pkgs.xdg-utils
    pkgs.nmgui
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = "phinger-cursors-dark";
    XCURSOR_SIZE = "24";
    GTK_THEME = "adw-gtk3-dark";
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  programs.dconf = {
    enable = lib.mkDefault true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            gtk-theme = "adw-gtk3-dark";
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

}

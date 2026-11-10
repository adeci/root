# Compositor-agnostic; pair with a session feature such as niri.
{
  nixos =
    {
      lib,
      pkgs,
      self,
      ...
    }:
    let
      gtk = "adw-gtk3-dark";
      icons = "Papirus-Dark";
      cursor = "phinger-cursors-dark";
      cursorSize = 24;

      easyeffectsPresets = pkgs.runCommand "easyeffects-presets" { } ''
        mkdir -p $out/share/easyeffects/input
        cp ${./presets}/*.json $out/share/easyeffects/input/
      '';
    in
    {
      imports = [
        self.modules.nixos.wrappers
        self.modules.nixos.handy
        self.modules.nixos.librewolf
      ];

      wrappers.kitty.enable = true;

      environment.systemPackages = [
        pkgs.nautilus
        pkgs.libnotify
        pkgs.jq
        pkgs.xdg-utils

        # audio
        pkgs.pavucontrol
        pkgs.pulseaudio
        pkgs.easyeffects
        easyeffectsPresets

        # network
        pkgs.nmgui

        # theme
        pkgs.adw-gtk3
        pkgs.papirus-icon-theme
        pkgs.phinger-cursors
      ];

      # Audio
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;

        # Set Shure MV7+ capture volume to 100% when connected.
        wireplumber.extraConfig."50-shure-mv7+" = {
          "monitor.alsa.rules" = [
            {
              matches = [
                { "node.name" = "~alsa_input.*Shure.*MV7.*"; }
              ];
              actions.update-props = {
                "node.volume" = 1.0;
              };
            }
          ];
        };
      };

      environment.pathsToLink = [ "/share/easyeffects" ];
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

      fonts.packages = [
        pkgs.nerd-fonts.caskaydia-mono
        pkgs.noto-fonts-color-emoji
      ];

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      # Servers keep clan's networkd default.
      networking.networkmanager.enable = true;
      networking.useNetworkd = false;

      # Secrets. GCR's SSH agent can't handle FIDO2 keys.
      services.gnome.gnome-keyring.enable = true;
      # Apps store secrets in the login keyring, never in one they create themselves.
      systemd.user.tmpfiles.rules = [
        "d %h/.local/share/keyrings 0700 - - -"
        "f+ %h/.local/share/keyrings/default 0600 - - - login"
      ];
      services.gnome.gcr-ssh-agent.enable = false;
      programs.ssh.startAgent = lib.mkDefault true;

      # Theme
      environment.sessionVariables = {
        XCURSOR_THEME = cursor;
        XCURSOR_SIZE = toString cursorSize;
        GTK_THEME = gtk;
        QT_QPA_PLATFORMTHEME = "gtk3";
      };

      programs.dconf = {
        enable = lib.mkDefault true;
        profiles.user.databases = [
          {
            settings."org/gnome/desktop/interface" = {
              gtk-theme = gtk;
              icon-theme = icons;
              color-scheme = "prefer-dark";
              cursor-theme = cursor;
              cursor-size = lib.gvariant.mkInt32 cursorSize;
            };
          }
        ];
      };
    };
}

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
      imports = [ self.modules.nixos.wrappers ];

      wrappers.kitty.enable = true;

      environment.systemPackages = [
        pkgs.nautilus
        pkgs.libnotify
        pkgs.jq
        pkgs.xdg-utils

        pkgs.pavucontrol
        pkgs.pulseaudio
        pkgs.easyeffects
        easyeffectsPresets

        pkgs.nmgui

        pkgs.adw-gtk3
        pkgs.papirus-icon-theme
        pkgs.phinger-cursors
      ];

      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;

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

      services.gnome.gnome-keyring.enable = true;
      # Apps store secrets in the login keyring, never in one they create themselves.
      systemd.user.tmpfiles.rules = [
        "d %h/.local/share/keyrings 0700 - - -"
        "f+ %h/.local/share/keyrings/default 0600 - - - login"
      ];
      # GCR's SSH agent can't handle FIDO2 keys.
      services.gnome.gcr-ssh-agent.enable = false;
      programs.ssh.startAgent = lib.mkDefault true;

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

  darwin =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    {
      imports = [ self.modules.darwin.wrappers ];

      wrappers.kitty.enable = true;

      # Prints the `defaults write` for each setting changed in System Settings.
      environment.systemPackages = [ pkgs.plistwatch ];

      # reattach makes Touch ID work inside tmux/screen.
      security.pam.services.sudo_local.touchIdAuth = true;
      security.pam.services.sudo_local.reattach = true;

      fonts.packages = [
        pkgs.nerd-fonts.caskaydia-cove
        pkgs.nerd-fonts.caskaydia-mono
      ];

      system.defaults = {
        dock = {
          autohide = true;
          mru-spaces = false;
          show-recents = false;
          # Disable hot corners
          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
        };
        finder = {
          AppleShowAllExtensions = true;
        };
        WindowManager = {
          EnableStandardClickToShowDesktop = false;
        };
        NSGlobalDomain = {
          AppleShowAllExtensions = true;
          InitialKeyRepeat = 15;
          KeyRepeat = 2;
          ApplePressAndHoldEnabled = false;
          NSAutomaticCapitalizationEnabled = false;
          NSAutomaticDashSubstitutionEnabled = false;
          NSAutomaticPeriodSubstitutionEnabled = false;
          NSAutomaticQuoteSubstitutionEnabled = false;
          NSAutomaticSpellingCorrectionEnabled = false;
        };
        controlcenter = {
          BatteryShowPercentage = true;
        };
        screencapture = {
          disable-shadow = true;
          type = "png";
        };
      };

      # nix-darwin rsyncs changed app bundles into /Applications/Nix Apps. macOS
      # keeps the old signature in LaunchServices and kills the next Finder or
      # Spotlight launch with "Launch Constraint Violation". Re-register the copies.
      system.activationScripts.postActivation.text = # bash
        lib.mkAfter ''
          if [[ -d "/Applications/Nix Apps" ]]; then
            launchctl asuser "$(/usr/bin/id -u -- ${config.system.primaryUser})" \
              sudo -H --user=${config.system.primaryUser} -- \
              /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
              -f -R "/Applications/Nix Apps" || true
          fi
        '';
    };
}

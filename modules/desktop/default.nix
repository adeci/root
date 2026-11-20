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
        # kitty and Emacs name this font in their configs.
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
      # facter enables DHCP everywhere, running dhcpcd next to NetworkManager's client.
      hardware.facter.detected.dhcp.enable = false;

      services.gnome.gnome-keyring.enable = true;
      # Apps use the login keyring, not one of their own.
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
      # niri takes the theme from its own config, not from XCURSOR_THEME.
      wrappers.niri.cursorTheme = cursor;

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
    let
      asUser = config.system.asPrimaryUser;
      screenshots = "${config.system.primaryUserHome}/Pictures/Screenshots";
    in
    {
      imports = [
        self.modules.darwin.primary-user
        self.modules.darwin.wrappers
      ];

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
          # Effectively no Dock: nothing pinned, ~15 minute delay.
          autohide-delay = 1000.0;
          persistent-apps = [ ];
          persistent-others = [ ];
          # Tiling WMs park hidden windows in a bottom corner; the Dock covers the sliver.
          orientation = "bottom";
          # Keeps Mission Control's thumbnails usable while windows are parked off-screen.
          expose-group-apps = true;
          mru-spaces = false;
          show-recents = false;
          # Disable hot corners
          wvous-tl-corner = 1;
          wvous-tr-corner = 1;
          wvous-bl-corner = 1;
          wvous-br-corner = 1;
        };
        # Separate Spaces confuse WMs about focus. Needs a logout.
        spaces.spans-displays = true;
        finder = {
          AppleShowAllExtensions = true;
          ShowPathbar = true;
          ShowStatusBar = true;
          FXPreferredViewStyle = "Nlsv";
          _FXSortFoldersFirst = true;
          NewWindowTarget = "Home";
          ShowHardDrivesOnDesktop = false;
          ShowExternalHardDrivesOnDesktop = false;
          ShowRemovableMediaOnDesktop = false;
          ShowMountedServersOnDesktop = false;
        };
        WindowManager = {
          EnableStandardClickToShowDesktop = false;
          GloballyEnabled = false;
        };
        menuExtraClock = {
          Show24Hour = false;
          ShowAMPM = true;
          ShowDate = 1;
          ShowDayOfWeek = true;
        };
        CustomUserPreferences = {
          "com.apple.desktopservices" = {
            DSDontWriteNetworkStores = true;
            DSDontWriteUSBStores = true;
          };
          # Spotlight as a launcher: apps and System Settings only. Each rule disables a source.
          "com.apple.Spotlight".EnabledPreferenceRules = [
            "Custom.relatedContents"
            "System.files"
            "System.folders"
            "System.iphoneApps"
            "System.menuItems"
            "com.apple.AddressBook"
            "com.apple.AppStore"
            "com.apple.Dictionary"
            "com.apple.Notes"
            "com.apple.Photos"
            "com.apple.Safari"
            "com.apple.VoiceMemos"
            "com.apple.calculator"
            "com.apple.iBooksX"
            "com.apple.iCal"
            "com.apple.mail"
            "com.apple.podcasts"
            "com.apple.reminders"
            "com.apple.shortcuts"
            "com.apple.tips"
          ];
          # "Help Apple improve search" off.
          "com.apple.assistant.support"."Search Queries Data Sharing Status" = 2;
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
          location = screenshots;
        };
      };

      # LaunchServices keeps stale signatures for Nix Apps: "Launch Constraint Violation".
      system.activationScripts.postActivation.text = # bash
        lib.mkAfter ''
          if [[ -d "/Applications/Nix Apps" ]]; then
            ${asUser} /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
              -f -R "/Applications/Nix Apps" || true
          fi

          # Idle never blanks or locks the screen; only the lid or a manual lock does.
          /usr/bin/pmset -a displaysleep 0
          ${asUser} /usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int 0

          # Spotlight opens on Option-D (shortcut 64); -dict-add leaves the other shortcuts alone.
          ${asUser} /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
            '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>100</integer><integer>2</integer><integer>524288</integer></array><key>type</key><string>standard</string></dict></dict>'
          ${asUser} /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

          # macOS silently saves to the desktop when this folder is missing.
          ${asUser} /bin/mkdir -p ${lib.escapeShellArg screenshots}
        '';
    };
}

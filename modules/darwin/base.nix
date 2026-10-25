# Fleet-wide Darwin defaults: nix, shell, fonts, system preferences, common tools.
{
  config,
  self,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  wrapped = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.nix-index-database.darwinModules.nix-index
  ];

  nix.enable = true;

  # nix-index with pre-built database: command-not-found handler + comma
  programs.nix-index-database.comma.enable = true;

  # Homebrew for macOS-native apps not available in nixpkgs
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [ "raycast" ];
  };

  # Touch ID for sudo (including inside tmux/screen)
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # Fonts
  fonts.packages = [
    pkgs.nerd-fonts.caskaydia-cove
    pkgs.nerd-fonts.caskaydia-mono
  ];

  # Wrapped shell as login shell
  # NOTE: nix-darwin doesn't change the macOS login shell via dscl.
  # Run once: sudo dscl . -change /Users/alex UserShell /bin/zsh <path-to-wrapped-zsh>
  programs.zsh.enable = true;
  programs.ssh.extraConfig = ''
    Host *
      SendEnv COLORTERM
  '';
  environment.pathsToLink = [ "/share/zsh" ];
  environment.shells = lib.mkDefault [ wrapped.zsh ];

  # macOS sshd sets no locale; without this, ssh sessions (and tmux started
  # from them) run in the C locale and mangle non-ASCII/Nerd Font glyphs.
  environment.variables.LANG = "en_US.UTF-8";

  # Wrapped tools available system-wide
  environment.systemPackages = [
    wrapped.zsh
    wrapped.git
    wrapped.kitty
    wrapped.tmux
    wrapped.btop
    self.packages.${pkgs.stdenv.hostPlatform.system}.nvim-dev
    inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli
  ];

  # System defaults
  system.primaryUser = self.users.alex.username;
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      show-recents = false;
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
      # Disable autocorrect annoyances
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
    # Disable hot corners
    dock.wvous-tl-corner = 1;
    dock.wvous-tr-corner = 1;
    dock.wvous-bl-corner = 1;
    dock.wvous-br-corner = 1;
  };

  nix.settings = lib.mkIf config.nix.enable {
    trusted-users = [
      "root"
      self.users.alex.username
    ];
  };

  # nix-darwin rsyncs changed app bundles into /Applications/Nix Apps. macOS
  # keeps the old signature in LaunchServices and kills the next Finder or
  # Raycast launch with "Launch Constraint Violation". Re-register the copies.
  system.activationScripts.postActivation.text = # bash
    lib.mkAfter ''
      if [[ -d "/Applications/Nix Apps" ]]; then
        launchctl asuser "$(/usr/bin/id -u -- ${config.system.primaryUser})" \
          sudo --user=${config.system.primaryUser} -- \
          /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
          -f -R "/Applications/Nix Apps" || true
      fi
    '';
}

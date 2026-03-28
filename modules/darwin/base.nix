# Fleet-wide Darwin defaults: nix, shell, fonts, system preferences, common tools.
{
  self,
  pkgs,
  inputs,
  ...
}:
let
  wrapped = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  nix.enable = true;

  # Homebrew for macOS-native apps not available in nixpkgs
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "raycast"
      "scroll-reverser"
    ];
  };

  # Touch ID for sudo (including inside tmux/screen)
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # Fonts
  fonts.packages = [
    pkgs.nerd-fonts.caskaydia-cove
  ];

  # Wrapped shell as login shell
  # NOTE: nix-darwin doesn't change the macOS login shell via dscl.
  # Run once: sudo dscl . -change /Users/alex UserShell /bin/zsh <path-to-wrapped-zsh>
  programs.zsh.enable = true;
  environment.shells = [ wrapped.zsh ];
  environment.pathsToLink = [ "/share/zsh" ];

  # Wrapped tools available system-wide
  environment.systemPackages = [
    wrapped.zsh
    wrapped.git
    wrapped.kitty
    wrapped.tmux
    wrapped.btop
    self.packages.${pkgs.stdenv.hostPlatform.system}.nixvim
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
}

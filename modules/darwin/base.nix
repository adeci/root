{
  config,
  pkgs,
  ...
}:
{
  nix.enable = true;

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # Fonts
  fonts.packages = [
    pkgs.nerd-fonts.caskaydia-cove
  ];

  # System defaults
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
      show-recents = false;
    };
    finder = {
      AppleShowAllExtensions = true;
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

  # Primary user
  system.primaryUser = config.adeci.primaryUser;

  # Fish shell (registers as valid login shell on Darwin)
  programs.fish.enable = true;
  programs.direnv.enable = true;
}

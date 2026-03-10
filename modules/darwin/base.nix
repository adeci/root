{
  config,
  pkgs,
  ...
}:
{
  nix.enable = true;

  # Touch ID for sudo (including inside tmux/screen)
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

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

  # Fish shell
  # NOTE: nix-darwin doesn't actually change the macOS login shell via dscl.
  # You must manually run: sudo dscl . -change /Users/<user> UserShell /bin/zsh /run/current-system/sw/bin/fish
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  programs.direnv.enable = true;
}

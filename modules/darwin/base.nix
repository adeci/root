{
  pkgs,
  self,
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

  # User
  system.primaryUser = self.users.alex.username;

  # Zsh shell

  # when migrating later to wrappers can use this
  # programs.zsh.enable = true;
  # environment.shells = [ self.packages.${pkgs.stdenv.hostPlatform.system}.zsh ];
  # environment.pathsToLink = [ "/share/zsh" ];

  # NOTE: nix-darwin doesn't actually change the macOS login shell via dscl.
  # You must manually run: sudo dscl . -change /Users/<user> UserShell /bin/zsh /run/current-system/sw/bin/zsh
  programs.zsh.enable = true;
  environment.shells = [ pkgs.zsh ];
}

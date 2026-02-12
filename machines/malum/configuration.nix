{ ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  nix.enable = true;
  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';

  # Touch ID for sudo
  security.pam.services.sudo_local.touchIdAuth = true;

  # System defaults
  system.defaults = {
    dock = {
      autohide = true;
      mru-spaces = false;
    };
    finder = {
      AppleShowAllExtensions = true;
    };
    NSGlobalDomain = {
      AppleShowAllExtensions = true;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
    };
  };

  # Primary user
  system.primaryUser = "alex";

  # Fish shell (registers as valid login shell on Darwin)
  programs.fish.enable = true;
  programs.direnv.enable = true;

  # Homebrew for GUI apps not in nixpkgs
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "1password"
      "slack"
      "discord"
    ];
  };
}

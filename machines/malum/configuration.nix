{ inputs, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
  ];

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
  users.users.alex = {
    name = "alex";
    home = "/Users/alex";
    shell = "/run/current-system/sw/bin/fish";
  };

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

  # Home-manager
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = {
      inherit inputs;
    };
    users.alex = {
      imports = [
        ../../home-manager/profiles/base.nix
        ../../home-manager/profiles/shell.nix
        ../../home-manager/profiles/dev.nix
        ../../home-manager/profiles/darwin.nix
      ];
      home.stateVersion = "24.11";
    };
  };
}

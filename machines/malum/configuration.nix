{ inputs, pkgs, ... }:
let
  dotpkgs = import ../../dotpkgs { inherit pkgs inputs; };
in
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  # system.stateVersion = 6; clan-core importer does this

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
  # homebrew = {
  #   enable = true;
  #   onActivation.cleanup = "zap";
  #   casks = [
  #     "1password"
  #     "slack"
  #     "discord"
  #   ];
  # };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    extraSpecialArgs = { inherit inputs dotpkgs; };
    sharedModules = [
      inputs.noctalia-shell.homeModules.default
      ../../modules/home-manager
    ];
  };

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.homeDirectory = "/Users/alex";
    home.stateVersion = "24.11";
  };
}

{ pkgs, lib, ... }:
{
  imports = [ ../../modules/darwin ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  adeci = {
    darwin-base.enable = true;
    homebrew.enable = true;
    home-manager.enable = true;
  };

  # Shopify-specific
  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';

  # Default shell (roster also sets this, mkForce to ensure it takes effect)
  users.users.alex.shell = lib.mkForce pkgs.fish;

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.homeDirectory = "/Users/alex";
    home.stateVersion = "24.11";
  };
}

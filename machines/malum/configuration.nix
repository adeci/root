{ self, ... }:
{
  imports = [
    self.users.alex.darwinModule

    ../../modules/darwin/base.nix
    ../../modules/darwin/home-manager.nix
    ../../modules/darwin/librewolf.nix
    ../../modules/darwin/shopify.nix
    ../../modules/darwin/homebrew.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  home-manager.users.alex = import ./home.nix;
}

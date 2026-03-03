{ ... }:
{
  imports = [
    ../../modules/home-manager/profiles/base.nix
    ../../modules/home-manager/profiles/darwin-desktop.nix
    ../../modules/home-manager/profiles/shopify.nix
  ];

  home.stateVersion = "25.11";
  home.homeDirectory = "/Users/alex";
}

{ ... }:
{
  imports = [
    ../../profiles/home-manager/base.nix
    ../../profiles/home-manager/darwin-desktop.nix
    ../../profiles/home-manager/shopify.nix
  ];

  home.stateVersion = "25.11";
  home.homeDirectory = "/Users/alex";
}

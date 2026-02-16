{ ... }:
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

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.homeDirectory = "/Users/alex";
    home.stateVersion = "24.11";
  };
}

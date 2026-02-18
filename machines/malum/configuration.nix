{ ... }:
{
  imports = [ ../../modules/darwin ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  adeci = {
    darwin-base.enable = true;
    homebrew.enable = true;
  };

  # Shopify-specific
  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';
}

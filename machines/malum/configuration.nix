{ ... }:
{
  imports = [ ../../modules/darwin ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  adeci = {
    darwin-base.enable = true;
    darwin-shopify.enable = true;
    homebrew.enable = true;
  };
}

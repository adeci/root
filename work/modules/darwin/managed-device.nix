{ lib, ... }:
{
  # Shopify's Determinate installation owns the Nix daemon and its configuration.
  nix.enable = lib.mkForce false;

  # Preserve Homebrew packages and taps managed by Shopify tooling.
  homebrew.onActivation.cleanup = lib.mkForce "none";
}

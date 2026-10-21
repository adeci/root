{ lib, ... }:
{
  # The preinstalled Determinate Nix owns the daemon and its configuration.
  nix.enable = lib.mkForce false;

  # Keep Homebrew packages installed outside this config.
  homebrew.onActivation.cleanup = lib.mkForce "none";
}

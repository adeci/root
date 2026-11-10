{
  darwin =
    { lib, ... }:
    {
      # The preinstalled Determinate Nix owns the daemon and its configuration.
      nix.enable = lib.mkForce false;
    };
}

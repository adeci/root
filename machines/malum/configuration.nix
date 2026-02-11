_: {
  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;

  nix.enable = true;
  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';
}

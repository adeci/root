_: {
  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';

  homebrew.casks = [
    "1password"
    "1password-cli"
    "slack"
  ];
}

_:
{
  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';
}

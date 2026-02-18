{ config, lib, ... }:
let
  cfg = config.adeci.darwin-shopify;
in
{
  options.adeci.darwin-shopify.enable = lib.mkEnableOption "Shopify-specific nix-darwin configuration";
  config = lib.mkIf cfg.enable {
    nix.extraOptions = ''
      !include nix.conf.d/shopify.conf
    '';
  };
}

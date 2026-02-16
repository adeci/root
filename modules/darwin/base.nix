{ config, lib, ... }:
let
  cfg = config.adeci.darwin-base;
in
{
  options.adeci.darwin-base.enable = lib.mkEnableOption "core Darwin defaults";
  config = lib.mkIf cfg.enable {
    nix.enable = true;

    # Touch ID for sudo
    security.pam.services.sudo_local.touchIdAuth = true;

    # System defaults
    system.defaults = {
      dock = {
        autohide = true;
        mru-spaces = false;
      };
      finder = {
        AppleShowAllExtensions = true;
      };
      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
      };
    };

    # Primary user
    system.primaryUser = "alex";

    # Fish shell (registers as valid login shell on Darwin)
    programs.fish.enable = true;
    programs.direnv.enable = true;
  };
}

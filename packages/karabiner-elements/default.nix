# Karabiner-Elements 14.13.0: nix-darwin's services.karabiner-elements has not
# worked since 15.0 (nix-darwin/nix-darwin#1041). Enzime pins the same.
{ pkgs, ... }:
pkgs.karabiner-elements.overrideAttrs (old: {
  version = "14.13.0";
  src = pkgs.fetchurl {
    inherit (old.src) url;
    hash = "sha256-gmJwoht/Tfm5qMecmq1N6PSAIfWOqsvuHU8VDJY8bLw=";
  };
  dontFixup = true;
  meta = old.meta // {
    platforms = [ "aarch64-darwin" ];
  };
})

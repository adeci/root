{
  inputs,
  lib,
  pkgs,
  ...
}:
lib.addMetaAttrs { platforms = [ "x86_64-linux" ]; } (
  pkgs.callPackage "${inputs.sdwire-cli}/default.nix" { }
)

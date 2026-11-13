{
  callPackage,
  inputs,
  lib,
}:
lib.addMetaAttrs { platforms = [ "x86_64-linux" ]; } (
  callPackage "${inputs.sdwire-cli}/default.nix" { }
)

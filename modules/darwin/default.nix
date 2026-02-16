{ lib, ... }:
let
  dir = builtins.readDir ./.;
  modules = lib.filterAttrs (
    n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix"
  ) dir;
in
{
  imports = lib.mapAttrsToList (n: _: ./${n}) modules;
}

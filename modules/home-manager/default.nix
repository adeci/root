{ lib, ... }:
let
  dir = builtins.readDir ./.;
  nixFiles = lib.filterAttrs (
    n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix"
  ) dir;
  dirs = lib.filterAttrs (n: t: t == "directory" && builtins.pathExists (./${n}/default.nix)) dir;
in
{
  imports = lib.mapAttrsToList (n: _: ./${n}) nixFiles ++ lib.mapAttrsToList (n: _: ./${n}) dirs;
}

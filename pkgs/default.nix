{ pkgs, inputs }:
let
  dirs = pkgs.lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./.);
in
pkgs.lib.mapAttrs (name: _: pkgs.callPackage ./${name} { inherit inputs; }) dirs

{ pkgs, inputs }:
let
  dirs = pkgs.lib.filterAttrs (name: t: t == "directory" && name != "wrapped") (builtins.readDir ./.);
in
pkgs.lib.mapAttrs (name: _: pkgs.callPackage ./${name} { inherit inputs; }) dirs

{
  pkgs,
  wrappers,
  nixvim,
}:
let
  moduleDirs = builtins.attrNames (
    pkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.)
  );
  importModule = dir: import ./${dir}/module.nix { inherit pkgs wrappers nixvim; };
in
builtins.foldl' (acc: dir: acc // (importModule dir)) { } moduleDirs

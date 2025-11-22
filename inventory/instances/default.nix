{ lib, ... }:
let
  instanceFiles = builtins.filter (name: name != "default.nix") (
    builtins.attrNames (
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (builtins.readDir ./.)
    )
  );

  importedInstances = map (file: import (./. + "/${file}")) instanceFiles;

  mergedInstances = lib.foldl' (
    acc: instanceSet: lib.recursiveUpdate acc instanceSet
  ) { } importedInstances;
in
{
  instances = mergedInstances;
}

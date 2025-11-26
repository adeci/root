{ lib, inputs, ... }:
let
  instanceFiles = builtins.filter (name: name != "default.nix") (
    builtins.attrNames (
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (builtins.readDir ./.)
    )
  );

  # Import each file, passing inputs if it's a function
  importInstance =
    file:
    let
      module = import (./. + "/${file}");
    in
    if builtins.isFunction module then module { inherit inputs; } else module;

  importedInstances = map importInstance instanceFiles;

  mergedInstances = lib.foldl' (
    acc: instanceSet: lib.recursiveUpdate acc instanceSet
  ) { } importedInstances;
in
{
  instances = mergedInstances;
}

{ lib, inputs, ... }:
let
  dirContents = builtins.readDir ./.;

  nixFiles = builtins.filter (name: name != "default.nix") (
    builtins.attrNames (
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) dirContents
    )
  );

  directories = builtins.attrNames (lib.filterAttrs (_name: type: type == "directory") dirContents);

  instanceEntries = nixFiles ++ directories;

  importInstance =
    entry:
    let
      module = import (./. + "/${entry}");
    in
    if builtins.isFunction module then module { inherit inputs; } else module;

  importedInstances = map importInstance instanceEntries;

  mergedInstances = lib.foldl' (
    acc: instanceSet: lib.recursiveUpdate acc instanceSet
  ) { } importedInstances;
in
{
  instances = mergedInstances;
}

{ lib, inputs, ... }:
let
  dirContents = builtins.readDir ./.;

  # Regular .nix files (excluding default.nix)
  nixFiles = builtins.filter (name: name != "default.nix") (
    builtins.attrNames (
      lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) dirContents
    )
  );

  # Directories (which contain a default.nix)
  directories = builtins.attrNames (lib.filterAttrs (_name: type: type == "directory") dirContents);

  instanceEntries = nixFiles ++ directories;

  # Import each entry, passing inputs if it's a function
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

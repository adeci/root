{ lib, ... }:
let
  dir = builtins.readDir ./.;
  excluded = [
    "buildbot-master.nix"
    "buildbot-worker.nix"
  ];
  modules = lib.filterAttrs (
    n: t: t == "regular" && lib.hasSuffix ".nix" n && n != "default.nix" && !builtins.elem n excluded
  ) dir;
in
{
  imports = lib.mapAttrsToList (n: _: ./${n}) modules;
}

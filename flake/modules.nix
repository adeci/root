# Each published module gets a `key`, so a feature imported by both a machine
# and another feature (handy imports keyd) is still only included once, and a
# `_class`, so importing a darwin half into a NixOS machine fails with a clear
# error. Both go on the module itself, not on a wrapper: modules are collected
# breadth-first, so a wrapper would push every feature a level deeper and
# reorder how definitions merge.
{ lib, ... }:
let
  mkModules =
    dir:
    let
      features =
        lib.mapAttrs' (entry: _: lib.nameValuePair (lib.removeSuffix ".nix" entry) (dir + "/${entry}"))
          (
            lib.filterAttrs (
              entry: type:
              (type == "regular" && lib.hasSuffix ".nix" entry)
              || (type == "directory" && builtins.pathExists (dir + "/${entry}/default.nix"))
            ) (builtins.readDir dir)
          );

      identify =
        class: path: module:
        let
          id = {
            _class = class;
            key = "${toString path}#${class}";
            _file = "${toString path}#${class}";
          };
        in
        if lib.isFunction module then
          lib.setFunctionArgs (args: module args // id) (lib.functionArgs module)
        else
          module // id;

      forClass =
        class:
        lib.mapAttrs (_: path: identify class path (import path).${class}) (
          lib.filterAttrs (_: path: (import path) ? ${class}) features
        );
    in
    {
      nixos = forClass "nixos";
      darwin = forClass "darwin";
    };
in
{
  options.flake.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.raw);
    default = { };
    description = "Machine features by class: self.modules.nixos.<name>, self.modules.darwin.<name>.";
  };

  # Helpers other flakes reuse (mkModules here, mkUser in users.nix).
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = { };
  };

  config.flake = {
    modules = mkModules ../modules;
    lib.mkModules = mkModules;
  };
}

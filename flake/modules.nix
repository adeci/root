{ lib, ... }:
let
  inherit (import ./lib.nix { inherit lib; }) nixEntries;

  mkModules =
    dir:
    let
      features = nixEntries dir;

      # `key` keeps a feature imported twice to one copy; `_class` rejects wrong-class imports.
      # Set on the module itself: wrapping it would reorder merging.
      identify =
        class: path: module:
        let
          identity = {
            _class = class;
            key = "${toString path}#${class}";
            _file = "${toString path}#${class}";
          };
        in
        if lib.isFunction module then
          lib.setFunctionArgs (args: module args // identity) (lib.functionArgs module)
        else
          module // identity;

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

  config.flake = {
    modules = mkModules ../modules;
    lib.mkModules = mkModules;
  };
}

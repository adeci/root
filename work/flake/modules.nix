# Publish work/modules/ features with root's helper (see root's flake/modules.nix).
{ inputs, lib, ... }:
{
  options.flake.modules = lib.mkOption {
    type = lib.types.lazyAttrsOf (lib.types.lazyAttrsOf lib.types.raw);
    default = { };
  };

  config.flake.modules = inputs.root.lib.mkModules ../modules;
}

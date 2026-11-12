{ inputs, ... }:
{
  flake.modules = inputs.root.lib.mkModules ../modules;
}

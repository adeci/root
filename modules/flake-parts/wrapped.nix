# Wrapped programs — config baked into packages via nix-wrapper-modules.
# Auto-discovers wrapper configs from modules/wrapped/*.nix.
# Each wrapper becomes a flake package: nix run .#<name>
{ inputs, lib, ... }:
let
  wrappedDir = ../wrapped;
  entries = lib.filterAttrs (
    name: type:
    (type == "regular" && lib.hasSuffix ".nix" name)
    || (type == "directory" && builtins.pathExists (wrappedDir + "/${name}/default.nix"))
  ) (builtins.readDir wrappedDir);
in
{
  imports = [ inputs.wrapper-modules.flakeModules.wrappers ];

  perSystem =
    { system, ... }:
    {
      wrappers.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };

  flake.wrappers = lib.mapAttrs' (
    name: type:
    let
      baseName = if type == "regular" then lib.removeSuffix ".nix" name else name;
    in
    lib.nameValuePair baseName {
      imports = [ (wrappedDir + "/${name}") ];
      _module.args.inputs = inputs;
    }
  ) entries;
}

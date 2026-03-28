# Wrapped programs — config baked into packages via nix-wrapper-modules.
# Each wrapper becomes a flake package: nix run .#<name>
#
# modules/wrapped/*.nix        — all platforms
# modules/wrapped/linux/*.nix  — linux only (excluded from darwin eval)
{ inputs, lib, ... }:
let
  # Discover wrapper modules in a directory, returning { name = { imports, ... }; }
  discover =
    dir:
    lib.mapAttrs'
      (
        filename: type:
        lib.nameValuePair (if type == "regular" then lib.removeSuffix ".nix" filename else filename) {
          imports = [ (dir + "/${filename}") ];
          _module.args.inputs = inputs;
        }
      )
      (
        lib.filterAttrs (
          name: type:
          (type == "regular" && lib.hasSuffix ".nix" name)
          || (type == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))
        ) (builtins.readDir dir)
      );

  crossPlatform = lib.removeAttrs (discover ../wrapped) [ "linux" ];
  linuxOnly = discover ../wrapped/linux;
in
{
  imports = [ inputs.wrapper-modules.flakeModules.wrappers ];

  flake.wrappers = crossPlatform // linuxOnly;

  perSystem =
    { system, ... }:
    {
      wrappers.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      # Linux-only wrappers reference linux-only inputs at eval time,
      # so they must be excluded on darwin (not just filtered at build time).
      wrappers.packages = lib.optionalAttrs (lib.hasSuffix "-darwin" system) (
        lib.mapAttrs (_: _: true) linuxOnly
      );
    };
}

# Wrapped programs — config baked into packages via nix-wrapper-modules.
# Auto-discovers wrapper configs from modules/wrapped/*.nix.
# Linux-only wrappers go in modules/wrapped/linux/*.nix.
# Each wrapper becomes a flake package: nix run .#<name>
{ inputs, lib, ... }:
let
  wrappedDir = ../wrapped;
  linuxDir = ../wrapped/linux;

  isModule =
    name: type:
    (type == "regular" && lib.hasSuffix ".nix" name)
    || (
      type == "directory" && name != "linux" && builtins.pathExists (wrappedDir + "/${name}/default.nix")
    );

  isLinuxModule =
    name: type:
    (type == "regular" && lib.hasSuffix ".nix" name)
    || (type == "directory" && builtins.pathExists (linuxDir + "/${name}/default.nix"));

  toWrapper = dir: name: type: {
    name = if type == "regular" then lib.removeSuffix ".nix" name else name;
    value = {
      imports = [ (dir + "/${name}") ];
      _module.args.inputs = inputs;
    };
  };

  crossPlatform = lib.mapAttrs' (
    name: type:
    let
      w = toWrapper wrappedDir name type;
    in
    lib.nameValuePair w.name w.value
  ) (lib.filterAttrs isModule (builtins.readDir wrappedDir));

  linuxOnly = lib.optionalAttrs (builtins.pathExists linuxDir) (
    lib.mapAttrs' (
      name: type:
      let
        w = toWrapper linuxDir name type;
      in
      lib.nameValuePair w.name w.value
    ) (lib.filterAttrs isLinuxModule (builtins.readDir linuxDir))
  );
in
{
  imports = [ inputs.wrapper-modules.flakeModules.wrappers ];

  perSystem =
    { system, ... }:
    let
      isDarwin = lib.hasSuffix "-darwin" system;
    in
    {
      wrappers.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      # Exclude linux-only wrappers on darwin (they reference linux-only inputs at eval time)
      wrappers.packages = lib.optionalAttrs isDarwin (lib.mapAttrs (_: _: true) linuxOnly);
    };

  flake.wrappers = crossPlatform // linuxOnly;
}

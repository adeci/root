{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (import ./lib.nix { inherit lib; }) nixEntries availablePackages;
in
{
  imports = [ inputs.wrapper-modules.flakeModules.wrappers ];

  flake.wrappers = lib.mapAttrs (_: path: {
    imports = [ path ];
    _module.args = { inherit self inputs; };
  }) (nixEntries ../wrappers);

  perSystem =
    { pkgs, ... }:
    {
      # Export as packages only the wrappers that build on this platform.
      wrappers.control_type = "build";
      wrappers.packages = lib.mapAttrs (_: _: true) (
        availablePackages pkgs.stdenv.hostPlatform (
          lib.mapAttrs (_: wrapper: wrapper.wrap { inherit pkgs; }) self.wrappers
        )
      );
    };
}

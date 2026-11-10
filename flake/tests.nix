# Built on demand, never as flake checks.
{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages = lib.optionalAttrs (system == "x86_64-linux") {
        leviathan-microvms-test = import ../machines/leviathan/tests/microvms.nix { inherit pkgs self; };
      };
    };
}

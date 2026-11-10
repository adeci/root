{ lib, inputs }:
let
  instancesModule = import ./instances { inherit lib inputs; };
in
{
  inherit (instancesModule) instances;
  machines = import ./machines.nix;
}

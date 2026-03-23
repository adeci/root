{ lib, inputs }:
let
  # Import instances from the instances folder
  instancesModule = import ./instances { inherit lib inputs; };
in
{
  # Expose instances and machines for clan-core
  inherit (instancesModule) instances;
  machines = import ./machines.nix;
}

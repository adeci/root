{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      mkTofuWorkspace = import ../tofu-workspace { inherit inputs lib pkgs; };
    in
    mkTofuWorkspace {
      name = "network";
      stateKey = "network.tfstate";
      providers = {
        random = pkgs.terraform-providers.hashicorp_random;
        routeros = pkgs.terraform-providers.terraform-routeros_routeros;
      };
      modules = [ ../../terranix/routeros ];
      appPrefix = "net";
      commands = [
        "init"
        "plan"
        "apply"
        "destroy"
        "state"
      ];
      scripts.state-rm-device = ./net-state-rm-device.sh;
    };
}

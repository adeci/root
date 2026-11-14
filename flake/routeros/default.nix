{ inputs, lib, ... }:
{
  perSystem =
    { pkgs, self', ... }:
    let
      mkTofuWorkspace = import ../tofu-workspace {
        inherit
          inputs
          lib
          pkgs
          self'
          ;
      };
    in
    {
      apps = mkTofuWorkspace {
        name = "network";
        stateKey = "network.tfstate";
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
    };
}

{
  config,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, self', ... }:
    let
      mkTofuWorkspace = import ./tofu-workspace {
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
        name = "cloud";
        stateKey = "tofu.tfstate";
        modules = [
          ../terranix/b2.nix
          ../terranix/cloudflare
          ../terranix/hcloud.nix
          ../terranix/tailscale.nix
        ]
        # A machine's own cloud resources, such as its server.
        ++ lib.filter builtins.pathExists (
          map (machine: ../machines/${machine}/terraform-configuration.nix) (
            lib.attrNames config.flake.inventory.machines
          )
        );
        appPrefix = "tf";
        commands = [
          "init"
          "plan"
          "apply"
          "output"
          "state"
          "destroy"
        ];
      };
    };
}

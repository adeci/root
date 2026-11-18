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
      mkTofuWorkspace = import ./tofu-workspace { inherit inputs lib pkgs; };
    in
    mkTofuWorkspace {
      name = "cloud";
      stateKey = "tofu.tfstate";
      providers = {
        b2 = self'.packages.terraform-provider-b2;
        cloudflare = pkgs.terraform-providers.cloudflare_cloudflare;
        hcloud = pkgs.terraform-providers.hetznercloud_hcloud;
        random = pkgs.terraform-providers.hashicorp_random;
        tailscale = pkgs.terraform-providers.tailscale_tailscale;
      };
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
}

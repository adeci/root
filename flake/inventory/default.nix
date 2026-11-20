# Checks inventory/ and publishes it as self.inventory.
{ lib, ... }:
let
  inventory =
    (lib.evalModules {
      modules = [
        ./schema.nix
        ./rules.nix
        ./references.nix
        ../../inventory/network.nix
        (
          { config, ... }:
          {
            b2 = import ../../inventory/b2.nix;
            cloudflare = import ../../inventory/cloudflare.nix;
            ingress = import ../../inventory/ingress.nix config;
            clanInstances = import ../../inventory/clan-instances.nix config;
            tailscalePolicy = import ../../inventory/tailscale-policy.nix config;
          }
        )
      ];
    }).config;

  problems = map (rule: rule.message) (lib.filter (rule: !rule.assertion) inventory.assertions);

  # schema.nix types everything but the rules and the other data files.
  typed = removeAttrs inventory [
    "assertions"
    "b2"
    "cloudflare"
    "ingress"
    "clanInstances"
    "tailscalePolicy"
  ];
in
{
  # Lists every problem; deepSeq so type errors fail even in values nothing reads.
  flake.inventory =
    if problems == [ ] then
      builtins.deepSeq typed (removeAttrs inventory [ "assertions" ])
    else
      throw "The inventory has problems:\n${lib.concatMapStrings (problem: "  - ${problem}\n") problems}";
}

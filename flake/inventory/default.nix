# Turns the data in inventory/ into self.inventory in three steps: check it against schema.nix, rules.nix and references.nix, list every problem, publish it.
{ lib, ... }:
let
  # 1. Check the data: network.nix against schema.nix and rules.nix, the other data files against references.nix.
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
            ingress = import ../../inventory/ingress.nix;
            clanInstances = import ../../inventory/clan-instances.nix config;
            tailscalePolicy = import ../../inventory/tailscale-policy.nix config;
          }
        )
      ];
    }).config;

  # 2. List every problem: each rule that doesn't hold.
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
  # 3. Publish self.inventory. Reading it fails while there are problems, listing them all; it reads every typed value first, so a type error fails even where nothing uses the value.
  flake.inventory =
    if problems == [ ] then
      builtins.deepSeq typed (removeAttrs inventory [ "assertions" ])
    else
      throw "The inventory has problems:\n${lib.concatMapStrings (problem: "  - ${problem}\n") problems}";
}

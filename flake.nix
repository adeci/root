{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    systems.url = "github:nix-systems/default/future-26.11";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/868c070a4a6e801ec4a69656000da150fdf68b9b.tar.gz";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";
    clan-core.inputs.flake-parts.follows = "flake-parts";
    clan-core.inputs.nix-darwin.follows = "nix-darwin";
    clan-core.inputs.systems.follows = "systems";

    terranix.url = "github:terranix/terranix";
    terranix.inputs.flake-parts.follows = "flake-parts";
    terranix.inputs.nixpkgs.follows = "nixpkgs";
    terranix.inputs.systems.follows = "systems";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";

    nix-rosetta-builder.url = "github:cpick/nix-rosetta-builder";
    nix-rosetta-builder.inputs.nixpkgs.follows = "nixpkgs";

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";
    jovian.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nixbot.url = "github:Mic92/nixbot";
    nixbot.inputs.nixpkgs.follows = "nixpkgs";
    nixbot.inputs.treefmt-nix.follows = "treefmt-nix";

    harmonia.url = "github:nix-community/harmonia";
    harmonia.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.flake-parts.follows = "flake-parts";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.inputs.treefmt-nix.follows = "treefmt-nix";
    llm-agents.inputs.systems.follows = "systems";

    mics-skills.url = "github:Mic92/mics-skills";
    mics-skills.inputs.nixpkgs.follows = "nixpkgs";
    mics-skills.inputs.treefmt-nix.follows = "treefmt-nix";

    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    wrapper-modules.inputs.nixpkgs.follows = "nixpkgs";

    lanzaboote.url = "github:nix-community/lanzaboote/v1.2.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";
    emacs-overlay.inputs.nixpkgs-stable.follows = "nixpkgs";

    sdwire-cli.url = "github:Badger-Embedded/sdwire-cli";
    sdwire-cli.flake = false;

    pelican.url = "github:adeci/vencord-pelican";
    pelican.inputs.nixpkgs.follows = "nixpkgs";

    mandate.url = "github:adeci/mandate/next";
    mandate.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.clan-core.flakeModules.default
        inputs.treefmt-nix.flakeModule
        ./flake
      ];
      debug = builtins ? currentSystem; # debug mode in repl
      systems = import inputs.systems;
    };
}

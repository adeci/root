{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # clan-core#8285 (drops the Nix 2.31 pin nixpkgs removed); back to main once merged.
    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/868c070a4a6e801ec4a69656000da150fdf68b9b.tar.gz";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";
    clan-core.inputs.flake-parts.follows = "flake-parts";
    clan-core.inputs.nix-darwin.follows = "nix-darwin";

    jovian.url = "github:Jovian-Experiments/Jovian-NixOS";
    jovian.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.flake-parts.follows = "flake-parts";

    buildbot-nix.url = "github:nix-community/buildbot-nix";

    harmonia.url = "github:nix-community/harmonia";
    harmonia.inputs.nixpkgs.follows = "nixpkgs";

    terranix.url = "github:terranix/terranix";
    terranix.inputs.flake-parts.follows = "flake-parts";
    terranix.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    #llm-agents.url = "github:adeci/llm-agents.nix?ref=adeci";
    llm-agents.url = "github:numtide/llm-agents.nix";
    # llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    # llm-agents.inputs.flake-parts.follows = "flake-parts";
    # llm-agents.inputs.treefmt-nix.follows = "treefmt-nix";

    mics-skills.url = "github:Mic92/mics-skills";
    mics-skills.inputs.nixpkgs.follows = "nixpkgs";
    mics-skills.inputs.treefmt-nix.follows = "treefmt-nix";

    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
    wrapper-modules.inputs.nixpkgs.follows = "nixpkgs";

    sdwire-cli.url = "github:Badger-Embedded/sdwire-cli";
    sdwire-cli.flake = false;

    drv-thru.url = "github:adeci/drv-thru";

    pelican.url = "github:adeci/vencord-pelican";
    pelican.inputs.nixpkgs.follows = "nixpkgs";

    nix-rosetta-builder.url = "github:cpick/nix-rosetta-builder";
    nix-rosetta-builder.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.clan-core.flakeModules.default
        inputs.treefmt-nix.flakeModule
        ./modules/flake-parts/flake-module.nix
      ];

      # debug mode in repl
      debug = builtins ? currentSystem;
    };
}

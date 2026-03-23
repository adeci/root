{
  description = "adeci's root flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    clan-core.url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    clan-core.inputs.nixpkgs.follows = "nixpkgs";
    clan-core.inputs.flake-parts.follows = "flake-parts";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    #wrappers.url = "github:lassulus/wrappers";
    wrappers.url = "github:adeci/wrappers?ref=btop";
    wrappers.inputs.nixpkgs.follows = "nixpkgs";

    noctalia-shell.url = "github:noctalia-dev/noctalia-shell";
    noctalia-shell.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.inputs.flake-parts.follows = "flake-parts";

    buildbot-nix.url = "github:nix-community/buildbot-nix";
    buildbot-nix.inputs.flake-parts.follows = "flake-parts";

    harmonia.url = "github:nix-community/harmonia";
    harmonia.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";
    llm-agents.inputs.nixpkgs.follows = "nixpkgs";
    llm-agents.inputs.flake-parts.follows = "flake-parts";
    llm-agents.inputs.treefmt-nix.follows = "treefmt-nix";

    mics-skills.url = "github:Mic92/mics-skills";
    mics-skills.inputs.nixpkgs.follows = "nixpkgs";
    mics-skills.inputs.flake-parts.follows = "flake-parts";
    mics-skills.inputs.treefmt-nix.follows = "treefmt-nix";

    opencrow.url = "github:pinpox/opencrow";
    opencrow.inputs.nixpkgs.follows = "nixpkgs";
    opencrow.inputs.treefmt-nix.follows = "treefmt-nix";

    sdwire-cli.url = "github:Badger-Embedded/sdwire-cli";
    sdwire-cli.inputs.nixpkgs.follows = "nixpkgs";

    grub2-themes.url = "github:vinceliuice/grub2-themes";
    grub2-themes.inputs.nixpkgs.follows = "nixpkgs";

    # https://github.com/niri-wm/niri/pull/3474
    niri.url = "github:adeci/niri?ref=window-rule-on-output";
    niri.inputs.nixpkgs.follows = "nixpkgs";

    # Sites
    devblog.url = "github:adeci/devblog";
    devblog.inputs.nixpkgs.follows = "nixpkgs";
    devblog.inputs.flake-parts.follows = "flake-parts";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      imports = [
        ./outputs/clan.nix
        ./outputs/packages.nix
        ./outputs/home-configurations.nix
        ./outputs/formatter.nix
        ./outputs/devshell.nix
        ./outputs/checks.nix
        ./modules/clan/roster/flake-module.nix
      ];
    };
}

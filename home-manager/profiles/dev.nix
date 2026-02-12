{ pkgs, inputs, ... }:
let
  pkgs-master = import inputs.nixpkgs-master {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  home.packages = with pkgs; [
    awscli2
    pkgs-master.claude-code-bin
    gh
    jujutsu
    nixpkgs-review
    nix-output-monitor
    socat
    lsof
    lazygit
  ];
}

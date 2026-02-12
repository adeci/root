{ pkgs, inputs, ... }:
let
  dotpkgs = import ../../dotpkgs { inherit pkgs inputs; };
in
{
  imports = [
    ../git.nix
  ];

  home.packages =
    with pkgs;
    [
      ripgrep
      fd
      eza
      bat
      wget
      unzip
      fzf
      tmux
      git
    ]
    ++ [
      dotpkgs.btop.wrapper
      dotpkgs.nixvim
    ];
}

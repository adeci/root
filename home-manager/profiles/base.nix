{ pkgs, inputs, ... }:
let
  dotpkgs = import ../../dotpkgs {
    inherit pkgs;
    wrappers = inputs.adeci-wrappers;
    nixvim = inputs.nixvim;
  };
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
      dotpkgs.btop
      dotpkgs.nixvim
    ];
}

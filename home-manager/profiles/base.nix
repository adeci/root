{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  dotpkgs = import ../../dotpkgs { inherit pkgs inputs; };
in
{
  imports = [
    ../git.nix
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    ../swayosd.nix
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
    ]
    ++ lib.optionals pkgs.stdenv.isLinux (
      with pkgs;
      [
        usbutils
        unrar
      ]
    );
}

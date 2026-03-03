{
  lib,
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
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
      git
    ]
    ++ [
      packages.btop
      packages.nixvim
    ]
    ++ lib.optionals pkgs.stdenv.isLinux (
      with pkgs;
      [
        usbutils
        unrar
      ]
    );
}

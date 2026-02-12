{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../swayosd.nix
  ];

  home.username = lib.mkDefault "alex";
  home.homeDirectory = lib.mkDefault "/home/alex";

  home.packages = with pkgs; [
    usbutils
    unrar
  ];
}

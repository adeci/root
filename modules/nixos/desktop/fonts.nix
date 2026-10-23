{ pkgs, ... }:
{
  fonts.packages = [
    pkgs.nerd-fonts.caskaydia-mono
    pkgs.noto-fonts-color-emoji
  ];
}

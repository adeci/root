{ pkgs, self, ... }:
{
  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.kitty
    pkgs.nautilus
    pkgs.libnotify
    pkgs.jq
    pkgs.xdg-utils
  ];
}

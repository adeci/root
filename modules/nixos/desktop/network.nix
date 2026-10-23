# Servers keep clan's networkd default.
{ pkgs, ... }:
{
  networking.networkmanager.enable = true;
  networking.useNetworkd = false;
  environment.systemPackages = [ pkgs.nmgui ];
}

{
  inputs,
  pkgs,
  ...
}:
{
  imports = [ ./desktop-base.nix ];

  nixpkgs.overlays = [ inputs.niri.overlays.default ];
  environment.systemPackages = [
    pkgs.kitty
    pkgs.nautilus
    pkgs.xwayland-satellite
  ];
  programs.niri.enable = true;
}

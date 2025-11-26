{
  inputs,
  pkgs,
  ...
}:
let
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ./sway-base.nix ];

  environment.systemPackages = [
    dotpkgs.waybar-desktop
  ];
}

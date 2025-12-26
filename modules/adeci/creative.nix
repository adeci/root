{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    blender
    freecad
    audacity
    obs-studio
  ];

}

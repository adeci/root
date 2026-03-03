{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    blender
    freecad
    audacity
    prusa-slicer
    obs-studio
  ];
}

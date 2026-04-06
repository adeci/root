{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    blender
    freecad
    openscad
    audacity
    prusa-slicer
    obs-studio
    gimp
  ];
}

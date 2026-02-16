{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.creative;
in
{
  options.adeci.creative.enable = lib.mkEnableOption "creative tools (Blender, FreeCAD, Audacity)";
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      blender
      freecad
      audacity
      prusa-slicer
      obs-studio
    ];
  };
}

{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    bambu-studio
    blender
    obs-studio
  ];

}

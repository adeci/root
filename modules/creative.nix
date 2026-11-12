{
  nixos =
    { pkgs, self, ... }:
    let
      packages = self.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      environment.systemPackages = with pkgs; [
        blender
        openscad
        audacity
        packages.prusa-slicer
        obs-studio
        gimp
      ];
    };
}

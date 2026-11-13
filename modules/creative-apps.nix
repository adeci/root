{
  nixos =
    { pkgs, self, ... }:
    let
      packages = self.packages.${pkgs.stdenv.hostPlatform.system};
    in
    {
      environment.systemPackages = [
        pkgs.blender
        pkgs.openscad
        pkgs.audacity
        packages.prusa-slicer
        pkgs.obs-studio
        pkgs.gimp
      ];
    };
}

{ pkgs, self, ... }:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = with pkgs; [
    blender
    # freecad # Temporarily disabled: PDAL 2.9.3 fails against current GDAL.
    openscad
    audacity
    # WebKit's gamepad support calls libmanette → hidapi. hid_get_device_info()
    # returns an invalid non-NULL pointer (0x31) for some hidraw devices.
    # packages.prusa-slicer carries the LD_PRELOAD shim.
    packages.prusa-slicer
    obs-studio
    gimp
  ];
}

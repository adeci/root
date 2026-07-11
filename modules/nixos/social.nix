# Social/communication apps.
{ pkgs, self, ... }:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    packages.element-desktop
    packages.signal-desktop
    packages.vesktop
  ];
}

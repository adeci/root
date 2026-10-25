# nvim with the small language servers, over base.nix's plain nvim.
{
  lib,
  pkgs,
  self,
  ...
}:
{
  environment.systemPackages = [
    (lib.hiPrio self.packages.${pkgs.stdenv.hostPlatform.system}.nvim-dev)
  ];
}

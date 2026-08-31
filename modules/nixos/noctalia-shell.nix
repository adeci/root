{
  pkgs,
  self,
  ...
}:
{
  environment.systemPackages = [
    self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-shell
  ];
}

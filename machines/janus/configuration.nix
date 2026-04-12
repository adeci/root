{
  self,
  ...
}:
{
  imports = [
    self.users.alex.nixosModule
    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    # ./modules/router.nix # DISABLED — re-enable after interface discovery on Qotom
  ];

  time.timeZone = "America/New_York";
}

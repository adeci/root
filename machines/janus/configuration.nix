{
  self,
  ...
}:
{
  imports = [
    self.users.alex.nixosModule
    ../../modules/nixos/base.nix
    ../../modules/nixos/dev.nix
    ../../modules/nixos/zsh.nix
    ./modules/router.nix
  ];

  time.timeZone = "America/New_York";
}

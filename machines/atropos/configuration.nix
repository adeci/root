{
  self,
  ...
}:
{
  imports = [
    self.users.alex.nixosModule
    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/zram.nix
  ];

  time.timeZone = "America/New_York";
}

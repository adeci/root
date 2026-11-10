{
  self,
  ...
}:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule
    base
    zsh
    llm-tools
    auto-pressure-gc
    zram
  ];

  time.timeZone = "America/New_York";
}

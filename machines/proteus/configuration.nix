{ self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule

    base
    nvim-dev
    zsh
    llm-tools
    auto-pressure-gc
    auto-timezone
    desktop
    librewolf
    niri
    noctalia
    amd-gpu
    zram
    keyd
    steam-deck
  ];
}

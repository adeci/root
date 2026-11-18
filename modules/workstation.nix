{
  nixos =
    { self, ... }:
    {
      imports = with self.modules.nixos; [
        base
        nvim-dev
        zsh
        auto-timezone
        auto-pressure-gc
        smartd
        desktop
        earwig
        librewolf
        bootvine
        niri
        noctalia
        niri-autologin
        keyboard
        zram
        laptop
        printing
        yubikey
      ];
    };
}

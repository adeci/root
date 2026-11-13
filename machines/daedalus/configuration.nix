{ self, ... }:
{
  imports = with self.modules.darwin; [
    self.users.alex.darwinModule

    base
    zsh
    auto-pressure-gc
    mac-security
  ];

  networking.computerName = "daedalus";

  # Headless: never sleeps, and comes back by itself after a power cut or a freeze.
  power = {
    sleep.computer = "never";
    restartAfterPowerFailure = true;
    restartAfterFreeze = true;
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;
}

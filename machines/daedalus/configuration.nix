{ self, ... }:
{
  imports = with self.modules.darwin; [
    self.users.alex.darwinModule

    base
    zsh
    auto-pressure-gc
    mac-security
    linux-builder
  ];

  networking.computerName = "daedalus";

  # Headless: never sleeps, and comes back by itself after a power cut or a freeze.
  power = {
    sleep.computer = "never";
    restartAfterPowerFailure = true;
    restartAfterFreeze = true;
  };

  # 16 GB: 8 GiB for the Linux VM, two Mac builds at once, the rest for macOS.
  nix.settings.max-jobs = 2;
  nix.linux-builder.config.virtualisation = {
    cores = 8;
    darwin-builder.memorySize = 8 * 1024;
    darwin-builder.diskSize = 40 * 1024;
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;
}

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

  # 16 GB: the Linux VM gets 8 GiB, at most two Mac builds run at once, macOS keeps the rest.
  nix.settings.max-jobs = 2;
  nix.linux-builder.config.virtualisation = {
    cores = 8;
    darwin-builder.memorySize = 8 * 1024;
    darwin-builder.diskSize = 40 * 1024;
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;
}

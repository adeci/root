{ self, ... }:
{
  imports = with self.modules.darwin; [
    self.users.alex.darwinModule
    self.users.fmzakari.darwinModule

    base
    zsh
    auto-pressure-gc
    mac-security
    linux-builder
  ];

  networking.computerName = "daedalus";
  system.primaryUser = self.users.alex.username;

  # Farid logs in over SSH as a standard user; macOS gave alex 501.
  users.users.fmzakari.uid = 502;
  nix.settings.trusted-users = [ self.users.fmzakari.username ];
  # Remote Login admits only admins and members of com.apple.access_ssh.
  system.activationScripts.postActivation.text = ''
    /usr/sbin/dseditgroup -o edit -a fmzakari -t user com.apple.access_ssh
  '';

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

{ pkgs, self, ... }:
{
  imports = with self.modules.nixos; [
    self.users.alex.nixosModule
    self.users.brittonr.nixosModule
    self.users.dima.nixosModule
    self.users.fmzakari.nixosModule
    self.users.jared.nixosModule
    self.users.tymon.nixosModule

    base
    zsh
    llm-tools
    smartd
    cloudflared
    auto-pressure-gc

    ./modules/microvms.nix
    ./modules/palworld
    ./modules/v100-compute.nix
  ];

  system.primaryUser = self.users.alex.username;
  cloudflared.token = self.inventory.cloudflare.tunnelToken;

  swapDevices = [
    {
      device = "/swapfile";
      size = 128 * 1024; # MiB
    }
  ];

  environment.systemPackages = [ pkgs.numactl ];
  wrappers.htop.enable = true;
  wrappers.btop.settings.cpu_sensor = "k10temp/Tctl";

  # THP tuned for ZGC.
  boot.kernelParams = [ "transparent_hugepage=madvise" ];
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/transparent_hugepage/shmem_enabled - - - - advise"
    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer"
    "w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - 1"
  ];

  # Keep two weeks of builds for the binary cache to serve.
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 14d";
  };

  nix.settings.max-jobs = 16;

  # farid's cursed stuff:

  services.guix.enable = true;
  services.eternal-terminal.enable = true;

  # FUSE-backed /bin and /usr/bin that show every executable on the requesting process's PATH.
  services.envfs.enable = true;

  # Tired of fighting NixOS: run foreign binaries pragmatically, even if it sweeps bugs under the rug.
  programs.nix-ld = {
    enable = true;
    libraries = [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib # numpy
    ];
  };
}

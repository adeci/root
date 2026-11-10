{
  pkgs,
  self,
  ...
}:
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
    ./modules/llm/host.nix
    ./modules/microvms.nix
    ./modules/palworld
    ./modules/v100-compute.nix
  ];

  time.timeZone = "America/New_York";

  swapDevices = [
    {
      device = "/swapfile";
      size = 128 * 1024; # MiB
    }
  ];

  environment.systemPackages = [ pkgs.numactl ];
  wrappers.big-htop.enable = true;
  wrappers.btop.settings.cpu_sensor = "k10temp/Tctl";

  # THP tuned for ZGC.
  boot.kernelParams = [ "transparent_hugepage=madvise" ];
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/transparent_hugepage/shmem_enabled - - - - advise"
    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer"
    "w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - 1"
  ];

  # Keep two weeks of builds for harmonia to serve.
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 14d";
  };

  nix.settings = {
    max-jobs = 16;
    trusted-users = [
      "root"
      self.users.alex.username
      self.users.brittonr.username
      self.users.dima.username
      self.users.fmzakari.username
    ];
  };

  # farid's cursed stuff:

  services.guix.enable = true;
  services.eternal-terminal.enable = true;

  # A fuse filesystem that dynamically populates contents of /bin
  # and /usr/bin/ so that it contains all executables from the PATH
  # of the requesting process.
  services.envfs.enable = true;

  programs = {

    # I got tired of facing NixOS issues
    # Let's be more pragmatic and try to run binaries sometimes
    # at the cost of sweeping bugs under the rug.
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib # numpy
      ];
    };

  };

}

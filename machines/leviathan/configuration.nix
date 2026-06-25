{
  inputs,
  pkgs,
  self,
  ...
}:
{

  imports = [
    inputs.drv-thru.nixosModules.default

    self.users.alex.nixosModule
    self.users.brittonr.nixosModule
    self.users.dima.nixosModule
    self.users.fmzakari.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/cloudflared.nix
    ./modules/buildbot.nix
    ./modules/llm/host.nix
    ./modules/v100-compute.nix
  ];

  time.timeZone = "America/New_York";

  environment.systemPackages = [
    pkgs.numactl
    inputs.drv-thru.packages.${pkgs.stdenv.hostPlatform.system}.default
    self.packages.${pkgs.stdenv.hostPlatform.system}.big-htop
  ];

  services.drv-thru.server = {
    enable = true;
    maxConcurrentBuilds = 3;
    trustedClients.alex = {
      publicKey = "4e898d570a913f2d7234d0fa3a101b418f1182cedd57a851b664177f1c2a4a28";
      maxBuildTime = "1h";
      maxUploadBytes = "20G";
    };
  };

  # Transparent Huge Pages configuration for ZGC
  boot.kernelParams = [ "transparent_hugepage=madvise" ];
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/transparent_hugepage/shmem_enabled - - - - advise"
    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer"
    "w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - 1"
  ];

  # Daily GC — keep 2 weeks of builds for harmonia to serve
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

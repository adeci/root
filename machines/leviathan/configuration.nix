{ pkgs, ... }:
{

  imports = [
    ../../modules/adeci/all.nix
    ../../modules/adeci/dev.nix
    ../../modules/adeci/shell.nix
  ];

  networking = {
    networkmanager.enable = true;
    hostName = "leviathan";
  };

  time.timeZone = "America/New_York";

  # Transparent Huge Pages configuration for ZGC
  boot.kernelParams = [ "transparent_hugepage=madvise" ];
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/transparent_hugepage/shmem_enabled - - - - advise"
    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer"
    "w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - 1"
  ];

  # Nix build server configuration for 256 logical core EPYC system
  nix.settings = {

    # How many derivations can we download from bincaches at the same time
    # https://bmcgee.ie/posts/2023/12/til-how-to-optimise-substitutions-in-nix/
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB

    max-jobs = 7; # Max parallel derivations locally
    # Prevent auto (256) which would cause massive overselling
    cores = 32; # Cores per derivation
    # 32 cores * 7 simul build jobs = at most 224 cores utilized, for total of ~88% system cpu utilization, leaving room for other processes, with this setup a single build job (SHOULD, some derivations do NOT respect this!) can use at most 12.5% of total system cpu

    trusted-users = [
      "root"
      "@wheel"
      "alex"
      "brittonr"
      "dima"
      "fmzakari"
    ];
  };

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

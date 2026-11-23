{
  lib,
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

    ./modules/microvms
    ./modules/palworld
    ./modules/v100-compute.nix
  ];

  system.primaryUser = self.users.alex.username;
  cloudflared.token = self.inventory.cloudflare.tunnelToken;

  # RAM overruns at peaks; a swapfile, unlike zram, moves the overflow out of memory.
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

  # SATA drives answer SMART only via the MegaRAID controller, not /dev/sd*.
  services.prometheus.exporters.smartctl.extraFlags = [ "--smartctl.device-exclude=^sd" ];
  systemd.services.prometheus-smartctl-exporter = {
    # smartd makes the ioctl node root-only; grant the exporter's group before each start.
    after = [ "smartd.service" ];
    serviceConfig = {
      DeviceAllow = lib.mkOverride 50 [ "char-megaraid_sas_ioctl rw" ];
      # smartctl looks the controller up in /proc/devices.
      ProcSubset = lib.mkForce "all";
      ExecStartPre = "+${lib.getExe' pkgs.acl "setfacl"} -m g:smartctl-exporter-access:rw /dev/megaraid_sas_ioctl_node";
    };
  };

  # Users' SSH clients multiplex more than sshd's default 10 sessions over one connection.
  services.openssh.settings.MaxSessions = 64;

  # A leftover process in a logged-out SSH session held the 13 Nov reboot for the full 90 s.
  systemd.units."session-.scope" = {
    text = ''
      [Scope]
      TimeoutStopSec=10s
    '';
    overrideStrategy = "asDropin";
  };

  nix.settings.max-jobs = 16;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

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

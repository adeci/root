{ inputs, pkgs, ... }:

let

  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };

in
{

  imports = [
    inputs.grub2-themes.nixosModules.default
    ../../modules/adeci/standard.nix
    ../../modules/adeci/dev.nix
    ../../modules/adeci/sway.nix
  ];

  # Leviathan remote builder configuration
  nix = {
    distributedBuilds = true;
    settings = {
      builders-use-substitutes = true;
      trusted-users = [
        "root"
        "alex"
      ];
    };
    buildMachines = [
      {
        protocol = "ssh-ng";
        hostName = "leviathan.cymric-daggertooth.ts.net";
        systems = [ "x86_64-linux" ];
        maxJobs = 7;
        speedFactor = 20;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
        sshUser = "alex";
      }
    ];
  };

  programs.ssh = {
    knownHosts = {
      leviathan = {
        hostNames = [
          "leviathan.cymric-daggertooth.ts.net"
          "192.168.50.189"
        ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEtV2xoOv+N4c5sg5oBqM/Xy+aZHf+5GHOhzXKYduXG";
      };
    };
    extraConfig = ''
      Host leviathan.cymric-daggertooth.ts.net
        IdentityAgent /run/user/3801/gcr/ssh
    '';
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva
    ];
  };

  networking = {
    networkmanager.enable = true;
    hostName = "modus";
  };

  #time.timeZone = "America/New_York";
  time.timeZone = "Asia/Bangkok";

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    os-prober
    framework-tool
    signal-desktop
    prismlauncher
    firefox
    blender
  ];

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
      useOSProber = true;
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "2880x1920";
      splashImage = grubWallpaper;
    };
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 60; # Balanced swapping
    "vm.dirty_ratio" = 15; # Reduce dirty pages
    "vm.dirty_background_ratio" = 5; # Earlier writeback
    "vm.overcommit_memory" = 1; # Allow overcommit for compilation
    "vm.page-cluster" = 0; # Optimize for ZRAM
  };

  zramSwap = {
    enable = true;
    algorithm = "lz4"; # compression
    memoryPercent = 87; # ~56GB of 64GB RAM
    priority = 100; # prio over disk swap
  };

  services = {
    fprintd.enable = true; # fingerprint sensor
    fwupd.enable = true; # framework bios/firmware updates

    # Keyd for dual-function keys (Caps Lock = Esc on tap, Ctrl on hold)
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
            };
          };
        };
      };
    };
  };

}

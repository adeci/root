{ inputs, pkgs, ... }:

let

  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};

  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };

in
{

  imports = [

    inputs.nixos-hardware.nixosModules.framework-13-7040-amd

    inputs.grub2-themes.nixosModules.default

    ../../modules/adeci/all.nix
    ../../modules/adeci/dev.nix

    ../../modules/adeci/sway.nix
    ../../modules/adeci/laptop.nix

    ../../modules/adeci/social.nix
    ../../modules/adeci/gaming.nix
    ../../modules/adeci/shell.nix
  ];

  environment.systemPackages =
    with pkgs;
    [
      imagemagick # required for grub2-theme
      os-prober
      firefox
      calibre
    ]
    ++ [
      dotpkgs.fw13-wm
    ];

  # btop needs rocm-smi and libdrm in ld path for gpu monitoring
  environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.rocmPackages.rocm-smi}/lib:${pkgs.libdrm}/lib";

  programs.ssh = {
    extraConfig = ''
      Host *
        AddKeysToAgent yes

      Host leviathan
        HostName leviathan.cymric-daggertooth.ts.net
        User alex
        ForwardAgent yes
    '';
  };

  hardware.amdgpu.opencl.enable = true;

  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
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

  nix.settings = {
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB

    trusted-users = [
      "root"
      "alex"
    ];
  };

}

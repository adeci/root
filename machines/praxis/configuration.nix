{ inputs, pkgs, ... }:

let

  wrappers = inputs.adeci-wrappers;
  praxis-waybar = (import ./modules/waybar/module.nix { inherit pkgs wrappers; }).waybar;
  praxis-swayosd = (import ./modules/swayosd/module.nix { inherit pkgs wrappers; }).swayosd;

in
{

  imports = [

    inputs.nixos-hardware.nixosModules.gpd-pocket-4

    ./modules/gpdp4-patches.nix

    ../../modules/adeci/all.nix
    ../../modules/adeci/dev.nix
    ../../modules/adeci/shell.nix

    ../../modules/adeci/niri.nix
    ../../modules/adeci/laptop.nix

    ../../modules/adeci/social.nix
    ../../modules/adeci/gaming.nix
    ../../modules/adeci/creative.nix
  ];

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_18;

  environment.systemPackages =
    with pkgs;
    [
      firefox
      calibre
      modem-manager-gui
      linux-wifi-hotspot
    ]
    ++ [
      praxis-waybar
      praxis-swayosd
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
    hostName = "praxis";
  };

  systemd.services.ModemManager = {
    wantedBy = [ "multi-user.target" ];
  };

  #time.timeZone = "America/New_York";
  time.timeZone = "Asia/Almaty";

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

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

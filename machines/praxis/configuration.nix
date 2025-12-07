{ inputs, pkgs, ... }:

let

  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};

in
{

  imports = [
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
      firefox
      calibre
      modem-manager-gui
    ]
    ++ [
      dotpkgs.gpd4-wm
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
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva
    ];
  };

  networking = {
    networkmanager.enable = true;
    hostName = "praxis";
  };

  systemd.services.ModemManager = {
    wantedBy = [ "multi-user.target" ];
  };

  #time.timeZone = "America/New_York";
  time.timeZone = "Asia/Bangkok";

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  boot.kernelParams = [
    "video=eDP-1:panel_orientation=right_side_up"
  ];

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

  # Fix gpd pocket 4 USB devices blocking suspend
  services.udev.extraRules = ''

    # Keep keyboard always-on but disable wakeup
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="258a", ATTRS{idProduct}=="000c", ATTR{power/wakeup}="disabled", ATTR{power/control}="on"

  '';
  # # Allow autosuspend for fingerprint reader
  # ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="2808", ATTRS{idProduct}=="0752", ATTR{power/wakeup}="disabled", ATTR{power/control}="auto"

  systemd.services.fix-touchscreen = {
    description = "Manually reload i2c_hid_acpi module to fix touchscreen";
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.kmod}/bin/modprobe -r i2c_hid_acpi";
      ExecStart = "${pkgs.kmod}/bin/modprobe i2c_hid_acpi";
    };
  };

  # Disable USB controller wakeup to prevent wakes from suspend
  systemd.services.disable-usb-wakeup = {
    description = "Disable XHC0 USB controller wakeup";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo XHC0 > /proc/acpi/wakeup'";
      RemainAfterExit = true;
    };
  };

  services = {

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

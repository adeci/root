{
  inputs,
  pkgs,
  lib,
  ...
}:

let

  dotpkgs = import ../../dotpkgs { inherit pkgs inputs; };

  praxis-waybar =
    (dotpkgs.waybar.apply {
      settings = {
        network.interface = "wlp195s0";
        modules-right = lib.mkForce [
          "network"
          "network#wwan"
          "bluetooth"
          "custom/cpu"
          "custom/gpu"
          "memory"
          "backlight"
          "pulseaudio"
          "custom/battery"
          "clock"
        ];
        "network#wwan" = {
          interface = "wwp197s0f4u1i4";
          format = "C ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
          format-wifi = "C ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
          format-ethernet = "C ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
          format-linked = "C ↓{bandwidthDownBytes:>7} ↑{bandwidthUpBytes:>7}";
          format-disconnected = "C ↓ ----/s ↑ ----/s";
          format-disabled = "C ↓ ----/s ↑ ----/s";
          tooltip = true;
          tooltip-format = "{ifname} {ipaddr}";
          tooltip-format-disconnected = "Disconnected";
          tooltip-format-disabled = "Disabled";
          on-click = "modem-manager-gui";
          interval = 1;
        };
      };
    }).wrapper;

in
{

  imports = [

    inputs.nixos-hardware.nixosModules.gpd-pocket-4

    ../../nix-modules/all.nix
    ../../nix-modules/dev.nix
    ../../nix-modules/shell.nix

    ../../nix-modules/niri.nix
    ../../nix-modules/laptop.nix
    ../../nix-modules/gpd-pocket-4-audio.nix

    ../../nix-modules/printing.nix
    ../../nix-modules/social.nix
    ../../nix-modules/gaming.nix
    ../../nix-modules/creative.nix
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

  time.timeZone = "America/New_York";
  #time.timeZone = "Asia/Almaty";

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

  # Fix gpd pocket 4 USB devices blocking suspend
  # Keep keyboard always-on but disable wakeup
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="258a", ATTRS{idProduct}=="000c", ATTR{power/wakeup}="disabled", ATTR{power/control}="on"
  '';

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

  # Run to fix intermittent touchscreen breakage after suspension
  systemd.services.fix-touchscreen = {
    description = "Manually reload i2c_hid_acpi module to fix touchscreen";
    serviceConfig = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.kmod}/bin/modprobe -r i2c_hid_acpi";
      ExecStart = "${pkgs.kmod}/bin/modprobe i2c_hid_acpi";
    };
  };

}

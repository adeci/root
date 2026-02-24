{
  inputs,
  pkgs,
  config,
  ...
}:

{

  imports = [

    inputs.nixos-hardware.nixosModules.gpd-pocket-4

    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    dev.enable = true;
    shell.enable = true;
    niri.enable = true;
    keyd.enable = true;
    amd-gpu.enable = true;
    ssh.enable = true;
    workstation.enable = true;
    laptop.enable = true;
    gpd-pocket-4-audio.enable = true;
    printing.enable = true;
    social.enable = true;
    gaming.enable = true;
    creative.enable = true;
    llm-secrets.enable = true;
  };

  boot.kernelPackages = pkgs.linuxKernel.packages.linux_6_18;

  environment.systemPackages = with pkgs; [
    firefox
    calibre
    modem-manager-gui
    linux-wifi-hotspot
  ];

  networking = {
    networkmanager.enable = true;
    hostName = "praxis";
  };

  systemd.services.ModemManager = {
    wantedBy = [ "multi-user.target" ];
  };

  # vm building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  nix.settings.trusted-users = [
    "root"
    config.adeci.primaryUser
  ];

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

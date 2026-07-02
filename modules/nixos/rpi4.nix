{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.raspberry-pi-4
  ];

  boot = {
    # nixos-hardware defaults to the downstream Raspberry Pi kernel, which is
    # often uncached. The generic aarch64 kernel boots Pi 4 and avoids local
    # kernel builds on small ARM machines.
    kernelPackages = lib.mkForce pkgs.linuxPackages;

    loader = {
      grub.enable = lib.mkForce false;
      generic-extlinux-compatible.enable = true;
    };
  };

  system.activationScripts.raspberryPi4BootFiles = # bash
    ''
            if [ -d /boot ]; then
              cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bootcode.bin /boot/
              cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup*.dat /boot/
              cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/start*.elf /boot/
              cp ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-*.dtb /boot/
              cp ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin /boot/u-boot-rpi4.bin
              cp ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin /boot/armstub8-gic.bin
              cat > /boot/config.txt <<'EOF'
      [pi4]
      kernel=u-boot-rpi4.bin
      enable_gic=1
      armstub=armstub8-gic.bin
      disable_overscan=1
      arm_boost=1

      [cm4]
      otg_mode=1

      [all]
      arm_64bit=1
      enable_uart=1
      avoid_warnings=1
      EOF
            fi
    '';
}

{
  nixos =
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
        # nixos-hardware's downstream Raspberry Pi kernel is often uncached; the generic aarch64 one boots a Pi 4 without local kernel builds.
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
            cp ${./config.txt} /boot/config.txt
          fi
        '';
    };
}

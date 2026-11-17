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

      # A boot file is written only when it differs, and then by rename: the SD card is spared, and a power cut cannot leave half a file.
      system.activationScripts.raspberryPi4BootFiles = # bash
        ''
          install_boot_file() {
            if ! ${pkgs.diffutils}/bin/cmp -s "$1" "$2"; then
              cp "$1" "$2.new"
              mv "$2.new" "$2"
            fi
          }
          if [ -d /boot ]; then
            for file in \
              ${pkgs.raspberrypifw}/share/raspberrypi/boot/bootcode.bin \
              ${pkgs.raspberrypifw}/share/raspberrypi/boot/fixup*.dat \
              ${pkgs.raspberrypifw}/share/raspberrypi/boot/start*.elf \
              ${pkgs.raspberrypifw}/share/raspberrypi/boot/bcm2711-rpi-*.dtb; do
              install_boot_file "$file" "/boot/$(basename "$file")"
            done
            install_boot_file ${pkgs.ubootRaspberryPi4_64bit}/u-boot.bin /boot/u-boot-rpi4.bin
            install_boot_file ${pkgs.raspberrypi-armstubs}/armstub8-gic.bin /boot/armstub8-gic.bin
            install_boot_file ${./config.txt} /boot/config.txt
          fi
        '';
    };
}

{ config, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  clan.core.vars.generators.luks-passphrase = {
    prompts.passphrase = {
      description = "Passphrase for the cryptroot LUKS volume";
      type = "hidden";
      persist = true;
    };

    files.passphrase.neededFor = "partitioning";
  };

  disko.devices.disk.main = {
    name = "main-3b63fa9dadf941fcbefbd3028749bcba";
    device = "/dev/nvme0n1";
    type = "disk";

    content = {
      type = "gpt";

      partitions = {
        ESP = {
          size = "2G";
          type = "EF00";

          content = {
            type = "filesystem";
            format = "vfat";
            extraArgs = [
              "-F"
              "32"
            ];
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";

          content = {
            type = "luks";
            name = "cryptroot";
            passwordFile = config.clan.core.vars.generators.luks-passphrase.files.passphrase.path;
            extraFormatArgs = [
              "--type"
              "luks2"
            ];
            settings.allowDiscards = false;

            content = {
              type = "btrfs";
              extraArgs = [
                "--force"
                "--label"
                "cryptroot"
              ];

              subvolumes = {
                "@root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                "@home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                "@log" = {
                  mountpoint = "/var/log";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };

                "@swap" = {
                  mountpoint = "/.swapvol";
                  mountOptions = [ "noatime" ];
                  swap.swapfile.size = "16G";
                };
              };
            };
          };
        };
      };
    };
  };
}

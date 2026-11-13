{
  # The machine sets disko.devices.disk.main.device.
  nixos =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      clan.core.vars.generators.luks-passphrase = {
        prompts.passphrase = {
          description = "Recovery passphrase for the cryptroot LUKS volume";
          type = "hidden";
          persist = true;
        };
        files.passphrase.neededFor = "partitioning";
      };

      disko.devices.disk.main = {
        # Partition labels derive from this name; the default "main" would collide with other disko-made disks such as installer sticks.
        name = config.networking.hostName;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # Lanzaboote keeps a signed UKI per generation on the ESP.
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
                settings = {
                  # The passphrase prompt stays until a TPM2 key is enrolled (once Secure Boot is on: systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-<host>-root), or when the TPM refuses.
                  crypttabExtraOpts = [ "tpm2-device=auto" ];
                };
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      };

      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.loader.efi.canTouchEfiVariables = true;

      # systemd-boot enrolls the generated keys only if the firmware is in Secure Boot setup mode.
      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
        configurationLimit = 10;
        autoGenerateKeys.enable = true;
        autoEnrollKeys = {
          enable = true;
          autoReboot = true;
        };
      };

      environment.systemPackages = [ pkgs.sbctl ];
    };
}

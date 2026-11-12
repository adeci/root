{
  # The machine sets disko.devices.disk.main.device, secureBootLuks.initrd and its initrd NIC driver; with Secure Boot on, seal the disk: systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-<host>-root
  nixos =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.secureBootLuks.initrd;
    in
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      options.secureBootLuks.initrd = {
        macAddress = lib.mkOption {
          type = lib.types.str;
          description = "MAC address of the NIC the initrd configures for SSH unlock.";
        };
        address = lib.mkOption {
          type = lib.types.str;
          example = "192.168.1.10/24";
          description = "Static initrd address with prefix length.";
        };
        gateway = lib.mkOption {
          type = lib.types.str;
          description = "Default gateway in the initrd.";
        };
        authorizedKeys = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          description = "SSH public keys allowed to unlock the disk.";
        };
      };

      config = {
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
                    # Falls back to the passphrase prompt (console or initrd SSH) until a TPM2 key is enrolled, or if the TPM refuses.
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

        # Static so the initrd is reachable even if DHCP hands out something else.
        boot.initrd.systemd.network.networks."10-lan" = {
          matchConfig.MACAddress = cfg.macAddress;
          address = [ cfg.address ];
          gateway = [ cfg.gateway ];
        };

        clan.core.vars.generators.initrd-ssh = {
          files.id_ed25519.neededFor = "activation";
          files."id_ed25519.pub".secret = false;
          runtimeInputs = [
            pkgs.coreutils
            pkgs.openssh
          ];
          script = ''
            ssh-keygen -t ed25519 -N "" -C "${config.networking.hostName}-initrd" -f "$out"/id_ed25519
          '';
        };

        # Unlock: ssh -p 2222 root@<lan ip>, then run systemd-tty-ask-password-agent.
        boot.initrd.network = {
          enable = true;
          ssh = {
            enable = true;
            port = 2222;
            inherit (cfg) authorizedKeys;
            hostKeys = [ config.clan.core.vars.generators.initrd-ssh.files.id_ed25519.path ];
          };
        };
      };
    };
}

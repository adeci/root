{
  # The machine sets disko.devices.disk.main.device and loads its NIC driver in
  # the initrd. Once Secure Boot is on, seal the disk to its state (PCR 7) by
  # hand:
  #   systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-partlabel/disk-<host>-root
  nixos =
    {
      config,
      inputs,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      host = self.resources.homelan.hosts.${config.networking.hostName};
      vlan = self.resources.homelan.vlans.${host.vlan};
    in
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
        # Partition labels derive from this name; the clan installer stick uses
        # "main" too, so the default would make /dev/disk/by-partlabel ambiguous.
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
                  # Falls back to the passphrase prompt (console or initrd SSH)
                  # until a TPM2 key is enrolled, or if the TPM refuses.
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

      # systemd-boot enrolls the generated keys only if the firmware is in Secure
      # Boot setup mode.
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
        matchConfig.MACAddress = host.mac;
        address = [ "${host.ip}/24" ];
        gateway = [ vlan.gateway ];
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
          authorizedKeys = self.users.alex.sshKeys;
          hostKeys = [ config.clan.core.vars.generators.initrd-ssh.files.id_ed25519.path ];
        };
      };
    };
}

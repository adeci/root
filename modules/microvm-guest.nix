{
  nixos =
    { config, lib, ... }:
    let
      cfg = config.microvmGuest;
    in
    {
      options.microvmGuest.adminKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "SSH public keys that log in as root.";
      };

      options.microvmGuest.seed = {
        image = lib.mkOption {
          type = lib.types.str;
          description = "Host path of the image holding the secrets; set by the host.";
        };
        label = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "seed";
        };
        sizeMiB = lib.mkOption {
          type = lib.types.ints.positive;
          readOnly = true;
          default = 8;
        };
        mountPoint = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "/run/seed";
        };
      };

      options.microvmGuest.secrets = lib.mkOption {
        default = { };
        description = ''
          Secrets the VM needs, each provided by its host from a clan vars
          generator, root-only at `path`.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, config, ... }:
            {
              options = {
                prompt = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
                script = lib.mkOption {
                  type = lib.types.nullOr lib.types.lines;
                  default = null;
                  description = ''Writes the value to "$out/value".'';
                };
                runtimeInputs = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [ ];
                };
                shared = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "One value for every VM on the host that declares this secret.";
                };
                seedPath = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = "secrets/${name}";
                  description = "Path inside the seed image.";
                };
                path = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = "${cfg.seed.mountPoint}/${config.seedPath}";
                };
              };
            }
          )
        );
      };

      config = {
        assertions = lib.mapAttrsToList (secretName: secret: {
          assertion = (secret.prompt == null) != (secret.script == null);
          message = "microvmGuest.secrets.${secretName}: set one of prompt or script";
        }) config.microvmGuest.secrets;

        microvmGuest.secrets.ssh-host-key = {
          script = ''
            ssh-keygen -q -t ed25519 -N "" -C ${config.networking.hostName} -f "$out/value"
            rm "$out/value.pub"
          '';
          runtimeInputs = [ config.programs.ssh.package ];
        };

        microvm = {
          shares = [
            {
              proto = "virtiofs";
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              readOnly = true;
            }
          ];
          volumes = [
            {
              image = "state.img";
              label = "state";
              mountPoint = "/var/lib";
              size = 1024;
            }
            {
              inherit (cfg.seed) image;
              mountPoint = null;
              autoCreate = false;
              readOnly = true;
              size = cfg.seed.sizeMiB;
            }
          ];
        };

        # Activation writes to /var/lib and /home before regular mounts.
        fileSystems =
          lib.genAttrs (lib.remove null (map (volume: volume.mountPoint) config.microvm.volumes)) (_: {
            neededForBoot = true;
          })
          // {
            ${cfg.seed.mountPoint} = {
              device = "/dev/disk/by-label/${cfg.seed.label}";
              fsType = "ext4";
              options = [ "ro" ];
            };
          };

        nix.enable = false;
        system.stateVersion = "26.11";

        networking = {
          useNetworkd = true;
          useDHCP = false;
        };
        systemd.network = {
          links."10-lan" = {
            matchConfig.MACAddress = (lib.head config.microvm.interfaces).mac;
            linkConfig.Name = "lan";
          };
          networks."10-lan" = {
            matchConfig.Name = "lan";
            networkConfig.DHCP = "ipv4";
            dhcpV4Config.ClientIdentifier = "mac";
          };
        };

        users.mutableUsers = false;
        users.users.root.openssh.authorizedKeys.keys = cfg.adminKeys;
        services.openssh = {
          enable = true;
          hostKeys = [
            {
              inherit (config.microvmGuest.secrets.ssh-host-key) path;
              type = "ed25519";
            }
          ];
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
          };
        };
      };
    };
}

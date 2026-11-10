{
  nixos =
    {
      config,
      lib,
      self,
      ...
    }:
    let
      name = config.networking.hostName;
    in
    {
      options.microvmGuest.secrets = lib.mkOption {
        default = { };
        description = ''
          Secrets the VM needs, each provided by its host from a clan vars
          generator, root-only at `path`.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }:
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
                path = lib.mkOption {
                  type = lib.types.str;
                  readOnly = true;
                  default = "/run/seed/secrets/${name}";
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
            ssh-keygen -q -t ed25519 -N "" -C ${name} -f "$out/value"
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
              image = "/run/microvm-seeds/${name}.img";
              mountPoint = null;
              autoCreate = false;
              readOnly = true;
              size = 8;
            }
          ];
        };

        # Activation writes to /var/lib and /home before regular mounts.
        fileSystems =
          lib.genAttrs (lib.remove null (map (volume: volume.mountPoint) config.microvm.volumes)) (_: {
            neededForBoot = true;
          })
          // {
            "/run/seed" = {
              device = "/dev/disk/by-label/seed";
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
        users.users.root.openssh.authorizedKeys.keys = self.users.alex.sshKeys;
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

# Two game-streaming seats, one V100 each, on nexus's tenant VLAN port.
{ self, ... }:
let
  inherit (self.resources.homelan) hosts;

  # Powers off when idle so leviathan gets the GPU back.
  gamingSeat =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      steam = lib.getExe config.programs.steam.package;
      uid = 1000;
      # Moonshine runs each Moonlight app as this unit in the gamer's manager.
      stream = "/sys/fs/cgroup/user.slice/user-${toString uid}.slice/user@${toString uid}.service/moonshine.slice/moonshine-session.service";
    in
    {
      imports = [ self.modules.nixos.wrappers ];

      options.gamingSeat.idleMinutes = lib.mkOption {
        type = lib.types.ints.positive;
        default = 15;
      };

      config = {
        microvmGuest.adminKeys = self.users.alex.sshKeys;

        microvmGuest.secrets.tailscale-gaming = {
          shared = true;
          prompt = "Tailscale auth key for gaming seats: reusable, not ephemeral, tagged tag:tenant,tag:gaming";
        };

        users.users.gamer = {
          isNormalUser = true;
          inherit uid;
          extraGroups = [
            "video"
            "render"
          ];
          openssh.authorizedKeys.keys = self.users.alex.sshKeys;
        };

        hardware = {
          nvidia = {
            package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
            open = false;
            modesetting.enable = true;
            nvidiaSettings = false;
            powerManagement.enable = false;
          };
          graphics.enable32Bit = true;
        };

        programs.steam = {
          enable = true;
          extraCompatPackages = [ pkgs.proton-ge-bin ];
        };

        wrappers.btop.enable = true;

        services = {
          xserver.videoDrivers = [ "nvidia" ];
          # Gives the render node a systemd unit to wait on.
          udev.extraRules = ''SUBSYSTEM=="drm", KERNEL=="renderD128", TAG+="systemd"'';

          tailscale = {
            enable = true;
            authKeyFile = config.microvmGuest.secrets.tailscale-gaming.path;
            openFirewall = true;
          };

          moonshine = {
            enable = true;
            package = self.packages.${pkgs.stdenv.hostPlatform.system}.moonshine;
            user = "gamer";
            firewallInterfaces = [
              "lan"
              "tailscale0"
            ];
            extraPackages = [ config.programs.steam.package ];
            settings = {
              name = config.networking.hostName;
              inhibit_sleep = false;
              # A disconnected game keeps running this long, to resume into.
              stream.timeout = 30 * 60;
              application = [
                {
                  title = "Steam";
                  command = [
                    steam
                    "steam://open/bigpicture"
                  ];
                  steam_integration = true;
                }
              ];
              application_scanner = [
                {
                  type = "steam";
                  library = "$HOME/.local/share/Steam";
                  command = [
                    steam
                    "-bigpicture"
                    "steam://rungameid/{game_id}"
                  ];
                }
              ];
            };
          };
        };

        systemd = {
          services = {
            # Needs the gamer's session bus and the render node the NVIDIA driver creates seconds into boot.
            moonshine = {
              requires = [
                "user@${toString uid}.service"
                "dev-dri-renderD128.device"
              ];
              after = [
                "user@${toString uid}.service"
                "dev-dri-renderD128.device"
              ];
            };

            idle-poweroff = {
              path = [
                config.systemd.package
                pkgs.jq
              ];
              serviceConfig.Type = "oneshot";
              script = ''
                mkdir -p /run/idle-poweroff
                cd /run/idle-poweroff
                rx=$(cat /sys/class/net/lan/statistics/rx_bytes)
                downloaded=$((rx - $(cat rx 2>/dev/null || echo "$rx")))
                echo "$rx" > rx
                if [ ! -e busy ] || [ -e ${stream} ] || [ "$downloaded" -ge $((60 << 20)) ] ||
                  loginctl list-sessions --json=short | jq -e 'any(.[]; .class == "user")' > /dev/null; then
                  date +%s > busy
                elif [ $(($(date +%s) - $(cat busy))) -ge ${toString (config.gamingSeat.idleMinutes * 60)} ]; then
                  systemctl poweroff
                fi
              '';
            };
          };

          timers.idle-poweroff = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1min";
              OnUnitActiveSec = "1min";
            };
          };
        };
      };
    };
in
{
  imports = [ self.modules.nixos.microvm-host ];

  # leviathan takes no address on the tenant VLAN.
  systemd.network = {
    netdevs."10-br-tenant".netdevConfig = {
      Name = "br-tenant";
      Kind = "bridge";
    };
    networks = {
      "10-tenant-uplink" = {
        matchConfig.Name = "eno12409np1";
        networkConfig.Bridge = "br-tenant";
        linkConfig.RequiredForOnline = "no";
      };
      "10-br-tenant" = {
        matchConfig.Name = "br-tenant";
        networkConfig = {
          LinkLocalAddressing = "no";
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
  };

  microvmHost = {
    bridge = "br-tenant";
    # Moonlight's wake button, from the trusted LAN.
    wakeOnLan = [ "eno12399np0" ];

    gpu.holders = [
      "nvidia-persistenced.service"
      "dcgm-hostengine.service"
      "dcgm-exporter.service"
      "llama-swap.service"
      "nvidia-container-toolkit-cdi-generator.service"
    ];

    # Each pinned to the CPUs nearest its GPU.
    vms = {
      scylla = {
        cid = 10;
        inherit (hosts.scylla) mac;
        vcpu = 16;
        memoryMiB = 24 * 1024;
        gpu = "0000:e2:00.0";
        cpus = "64-79 192-207";
        volumes.home = {
          mountPoint = "/home";
          sizeMiB = 256 * 1024;
        };
        config = gamingSeat;
      };

      charybdis = {
        cid = 11;
        inherit (hosts.charybdis) mac;
        vcpu = 16;
        memoryMiB = 24 * 1024;
        gpu = "0000:21:00.0";
        cpus = "32-47 160-175";
        volumes.home = {
          mountPoint = "/home";
          sizeMiB = 128 * 1024;
        };
        config = gamingSeat;
      };
    };
  };
}

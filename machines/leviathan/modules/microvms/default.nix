# Game-streaming seats, one V100 each.
{ self, ... }:
let
  inherit (self.inventory.lan) hosts;

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

      idlePoweroff = pkgs.writeShellApplication {
        name = "idle-poweroff";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.gawk
          pkgs.iptables
          pkgs.jq
          config.systemd.package
        ];
        text = builtins.readFile ./idle-poweroff.sh;
      };

      # World of Warcraft and Blizzard's other games have no Linux version and are not on Steam.
      battlenet = pkgs.writeShellApplication {
        name = "battlenet";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.umu-launcher
          pkgs.util-linux
        ];
        runtimeEnv.PROTONPATH = pkgs.proton-ge-bin.steamcompattool;
        text = builtins.readFile ./battlenet.sh;
      };

      # Moonshine's compositor shows one window at a time and can't resize it. A program with several windows,
      # or one whose window starts too small to use, runs inside labwc.
      windowed = title: program: {
        inherit title;
        command = [
          (lib.getExe pkgs.labwc)
          "--session"
          program
        ];
        # labwc stalls at start inside Moonshine's compositor with hardware cursors.
        env.WLR_NO_HARDWARE_CURSORS = "1";
      };

      # The desktop is a bar: a button for each of these, the open windows, and a clock.
      desktopPrograms = [
        {
          name = "Files";
          program = lib.getExe pkgs.pcmanfm;
        }
        {
          name = "Terminal";
          program = lib.getExe pkgs.foot;
        }
        {
          name = "Browser";
          program = lib.getExe pkgs.firefox;
        }
        {
          name = "Heroic";
          program = lib.getExe pkgs.heroic;
        }
        {
          name = "Lutris";
          program = lib.getExe pkgs.lutris;
        }
        {
          name = "Bottles";
          program = lib.getExe pkgs.bottles;
        }
      ];
      bar = pkgs.writeText "waybar.json" (
        builtins.toJSON (
          {
            position = "bottom";
            height = 36;
            modules-left = map (entry: "custom/${entry.name}") desktopPrograms;
            modules-center = [ "wlr/taskbar" ];
            modules-right = [ "clock" ];
            "wlr/taskbar" = {
              format = "{title}";
              on-click = "activate";
            };
          }
          // lib.listToAttrs (
            map (entry: {
              name = "custom/${entry.name}";
              value = {
                format = entry.name;
                on-click = entry.program;
              };
            }) desktopPrograms
          )
        )
      );
      barStyle = pkgs.writeText "waybar.css" ''
        * { font-size: 15px; }
        .module, #taskbar button { padding: 0 14px; }
      '';
    in
    {
      imports = [ self.modules.nixos.wrappers ];

      options.gamingSeat = {
        idleMinutes = lib.mkOption {
          type = lib.types.ints.positive;
          default = 15;
        };
        resumeMinutes = lib.mkOption {
          type = lib.types.ints.positive;
          default = 30;
          description = "How long a game nobody is connected to keeps running, to resume into.";
        };
      };

      config = {
        microvmGuest.adminKeys = self.users.alex.sshKeys;

        # Steam reads thousands of small files from the store at every start; over the host's share that took 20 s.
        microvmGuest.storeOnDisk = true;

        # Steam's home screen shows an error without a time zone.
        time.timeZone = self.users.alex.timeZone;

        # Steam's Deck interface waits ten seconds for NetworkManager before it signs in.
        networking.networkmanager.enable = true;
        systemd.network = {
          networks."10-lan".enable = false;
          wait-online.enable = false;
        };

        # Games don't ask for 2 MiB pages; with this they get them. Random memory reads took 29% less time.
        boot.kernelParams = [ "transparent_hugepage=always" ];

        # Proton uses it in place of fsync when the device is there.
        boot.kernelModules = [ "ntsync" ];

        # The desktop's terminal wants a monospace font.
        fonts.packages = [ pkgs.dejavu_fonts ];

        # Counts what a Moonlight client sends to Moonshine's control port, for the idle check. Mangle sees the
        # packets before the firewall's rule for established connections takes them.
        networking.firewall.extraCommands = ''
          iptables -t mangle -C PREROUTING -p udp --dport 47999 -m comment --comment moonlight-client 2> /dev/null ||
            iptables -t mangle -A PREROUTING -p udp --dport 47999 -m comment --comment moonlight-client
        '';

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
              # Moonshine can't tell that a client has gone and would keep the game for this long. The idle
              # check ends it sooner; this only has to outlast a long download.
              stream.timeout = 24 * 60 * 60;
              application = [
                {
                  title = "Steam";
                  boxart = "${pkgs.steam-unwrapped}/share/icons/hicolor/256x256/apps/steam.png";
                  command = [
                    steam
                    "steam://open/bigpicture"
                  ];
                  steam_integration = true;
                }
                {
                  title = "Battle.net";
                  boxart = "${pkgs.fetchurl {
                    url = "https://upload.wikimedia.org/wikipedia/commons/2/23/Blizzard_Battle.net_logo.png";
                    hash = "sha256-rshBtQHCiNlgfN3ir2bITC30PSOesE42iUPleP6B4U8=";
                  }}";
                  command = [ (lib.getExe battlenet) ];
                }
                (
                  windowed "WoW addons" (lib.getExe pkgs.wowup-cf)
                  // {
                    boxart = "${pkgs.wowup-cf}/share/icons/hicolor/512x512/apps/wowup-cf.png";
                  }
                )
                (
                  windowed "Dolphin" (lib.getExe pkgs.dolphin-emu)
                  // {
                    boxart = "${pkgs.dolphin-emu}/share/icons/hicolor/256x256/apps/dolphin-emu.png";
                  }
                )
                (
                  windowed "Desktop" "${lib.getExe pkgs.waybar} --config ${bar} --style ${barStyle}"
                  // {
                    # Moonshine reads no SVG.
                    boxart = "${pkgs.runCommand "desktop-cover.png" { } ''
                      ${lib.getExe' pkgs.librsvg "rsvg-convert"} --width 512 --height 512 --output $out \
                        ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/scalable/devices/computer.svg
                    ''}";
                  }
                )
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
                # Games installed through the desktop's launchers show up in Moonlight next to Steam's.
                {
                  type = "heroic";
                  command = [
                    (lib.getExe pkgs.heroic)
                    "--no-gui"
                    "heroic://launch?appName={app_name}&runner={runner}"
                  ];
                }
                {
                  type = "lutris";
                  command = [
                    (lib.getExe pkgs.lutris)
                    "lutris:rungame/{slug}"
                  ];
                }
                {
                  type = "bottles";
                  command = [
                    "${pkgs.bottles}/bin/bottles-cli"
                    "run"
                    "-b"
                    "{bottle}"
                    "--program-id"
                    "{program_id}"
                  ];
                }
              ];
            };
          };
        };

        systemd = {
          services = {
            # Needs the gamer's session bus and the render node, which appears seconds into boot.
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

            idle-poweroff.serviceConfig = {
              Type = "oneshot";
              ExecStart = lib.concatStringsSep " " [
                (lib.getExe idlePoweroff)
                stream
                (toString (config.gamingSeat.idleMinutes * 60))
                (toString (config.gamingSeat.resumeMinutes * 60))
              ];
            };
          };

          timers.idle-poweroff = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnBootSec = "1min";
              OnUnitActiveSec = "1min";
            };
          };

          # Without a cursor theme named "default", Steam's pointer is a small X11 arrow.
          user.tmpfiles.users.gamer.rules = [
            "L+ %h/.local/share/icons/default - - - - ${pkgs.adwaita-icon-theme}/share/icons/Adwaita"
          ];
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
      "nvidia-container-toolkit-cdi-generator.service"
    ];

    # Each pinned to the CPUs nearest its GPU. Those nodes have no memory, so it comes from the nearest one that has.
    vms = {
      scylla = {
        cid = 10;
        inherit (hosts.scylla) mac;
        vcpu = 16;
        memoryMiB = 24 * 1024;
        gpu = "0000:e2:00.0";
        cpus = "64-79 192-207";
        memoryNode = 5;
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
        memoryNode = 1;
        volumes.home = {
          mountPoint = "/home";
          sizeMiB = 256 * 1024;
        };
        config = gamingSeat;
      };
    };
  };
}

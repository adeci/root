{ clanLib, lib, ... }:
{
  _class = "clan.service";

  manifest = {
    name = "@adeci/remote-builder";
    description = "Nix remote builder with per-client SSH keys and a dedicated build user";
    categories = [ "System" ];
    readme = builtins.readFile ./README.md;
  };

  roles.server = {
    description = "Machine that accepts remote build jobs via a dedicated nix user";

    interface =
      { lib, ... }:
      {
        options = {
          systems = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "x86_64-linux" ];
            description = "System types this builder can build for";
          };

          maxJobs = lib.mkOption {
            type = lib.types.int;
            default = 4;
            description = "Maximum number of concurrent build jobs";
          };

          speedFactor = lib.mkOption {
            type = lib.types.int;
            default = 1;
            description = "Speed factor relative to other builders (higher = preferred)";
          };

          supportedFeatures = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "nixos-test"
              "big-parallel"
              "kvm"
            ];
            description = "Supported build features";
          };

          linuxBuilder = lib.mkOption {
            type = lib.types.nullOr (
              lib.types.submodule {
                options = {
                  systems = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ "aarch64-linux" ];
                    description = "System types the VM builds for";
                  };
                  maxJobs = lib.mkOption {
                    type = lib.types.int;
                    default = 4;
                    description = "Maximum number of concurrent build jobs in the VM";
                  };
                  supportedFeatures = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ "big-parallel" ];
                    description = "Build features the VM supports; kvm turns on nested virtualization";
                  };
                };
              }
            );
            default = null;
            description = ''
              nix-darwin servers with the linux-builder feature: its Linux VM, which
              clients reach by jumping through this server over SSH.
            '';
          };

          externalKeys = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              SSH public keys from external users (friends not in your clan)
              to authorize on the nix build user.
            '';
            example = [ "ssh-ed25519 AAAA... friend" ];
          };
        };
      };

    perInstance =
      {
        instanceName,
        settings,
        roles,
        ...
      }:
      let
        # Clients without a public key yet are skipped; servers authorize them on their next deploy.
        authorizedKeys =
          directory:
          lib.filter (key: key != "") (
            lib.mapAttrsToList (
              clientName: _:
              lib.strings.trim (
                clanLib.getPublicValue {
                  flake = directory;
                  machine = clientName;
                  generator = instanceName;
                  file = "id_ed25519.pub";
                  default = "";
                }
              )
            ) (roles.client.machines or { })
          )
          ++ settings.externalKeys;

        shared =
          { config, ... }:
          {
            users.users.nix.openssh.authorizedKeys.keys = authorizedKeys config.clan.core.settings.directory;
            nix.settings.trusted-users = [ "nix" ];
          };
      in
      {
        nixosModule =
          { pkgs, ... }:
          {
            imports = [ shared ];

            users.users.nix = {
              isSystemUser = true;
              home = "/var/empty";
              group = "nix";
              shell = pkgs.bashInteractive;
            };
            users.groups.nix = { };
          };

        darwinModule =
          { config, ... }:
          {
            imports = [ shared ];

            assertions = [
              {
                assertion = settings.linuxBuilder == null || config.nix.linux-builder.enable;
                message = "@adeci/remote-builder: linuxBuilder needs the linux-builder feature.";
              }
            ];

            # nix-darwin only creates and changes the users it owns.
            users.knownUsers = [ "nix" ];
            users.users.nix = {
              uid = 550;
              home = "/var/empty";
              # zsh reads nix-darwin's /etc/zshenv even for `ssh … nix-daemon --stdio`, which puts nix-daemon on PATH.
              shell = "/bin/zsh";
            };

            # Remote Login limited to "Only these users" admits only members of com.apple.access_ssh.
            system.activationScripts.postActivation.text = ''
              if /usr/bin/dscl . -read /Groups/com.apple.access_ssh >/dev/null 2>&1; then
                /usr/sbin/dseditgroup -o edit -a nix -t user com.apple.access_ssh
              fi
            '';

            nix.linux-builder = lib.mkIf (settings.linuxBuilder != null) {
              inherit (settings.linuxBuilder) systems maxJobs supportedFeatures;
              config = {
                users.users.builder.openssh.authorizedKeys.keys =
                  authorizedKeys config.clan.core.settings.directory;
                # The builder profile forces its own key file; equal priority keeps the standard one too.
                services.openssh.authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];
              };
            };
          };
      };
  };

  roles.client = {
    description = "Machine that offloads builds to remote builders";

    interface =
      { lib, ... }:
      {
        options.offload = lib.mkOption {
          type = lib.types.enum [
            "foreign"
            "all"
            "none"
          ];
          default = "foreign";
          description = ''
            Which builds go remote automatically: only systems this machine can't
            build itself (foreign), anything a server supports (all), or nothing
            (none). /etc/nix/machines-all always lists every server for opting in
            per build.
          '';
        };
      };

    perInstance =
      {
        instanceName,
        roles,
        settings,
        ...
      }:
      let
        client =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            machineName = config.clan.core.settings.machine.name;
            inherit (config.clan.core.settings) domain;
            servers = lib.removeAttrs roles.server.machines [ machineName ];

            # x86_64 Linux builds i686 natively; emulated systems are read from binfmt, as nix.settings depends on distributedBuilds.
            system = pkgs.stdenv.hostPlatform.system;
            nativeSystems = [
              system
            ]
            ++ (config.boot.binfmt.emulatedSystems or [ ])
            ++ lib.optional (system == "x86_64-linux") "i686-linux";

            key = config.clan.core.vars.generators.${instanceName}.files.id_ed25519.path;

            buildMachines = lib.concatLists (
              lib.mapAttrsToList (
                serverName: server:
                [
                  {
                    hostName = "${serverName}.${domain}";
                    inherit (server.settings)
                      systems
                      maxJobs
                      speedFactor
                      supportedFeatures
                      ;
                    protocol = "ssh-ng";
                    sshUser = "nix";
                    sshKey = key;
                  }
                ]
                ++ lib.optional (server.settings.linuxBuilder != null) {
                  hostName = "${serverName}-linux-builder";
                  inherit (server.settings.linuxBuilder) systems maxJobs supportedFeatures;
                  inherit (server.settings) speedFactor;
                  protocol = "ssh-ng";
                  sshUser = "builder";
                  sshKey = key;
                }
              ) servers
            );

            offloadMachines =
              {
                all = buildMachines;
                none = [ ];
                foreign = lib.filter (machine: machine.systems != [ ]) (
                  map (
                    machine: machine // { systems = lib.subtractLists nativeSystems machine.systems; }
                  ) buildMachines
                );
              }
              .${settings.offload};

            machinesFileLine =
              machine:
              lib.concatStringsSep " " [
                "${machine.protocol}://${machine.sshUser}@${machine.hostName}"
                (lib.concatStringsSep "," machine.systems)
                machine.sshKey
                (toString machine.maxJobs)
                (toString machine.speedFactor)
                (
                  if machine.supportedFeatures == [ ] then "-" else lib.concatStringsSep "," machine.supportedFeatures
                )
                "-"
                "-"
              ];

            serverSsh = hostName: ''
              Host ${hostName}
                StrictHostKeyChecking accept-new

              # Nix manages its own SSH connections: disable any ControlMaster a user/system ssh config enables for this host.
              # An unreachable builder should fail the build in seconds, not after the TCP timeout.
              # The key is named here too for jumps to the server's Linux VM, which don't get Nix's -i.
              Match host ${hostName} user nix
                IdentityFile ${key}
                ControlMaster no
                ControlPath none
                ConnectTimeout 10
            '';

            # nix-darwin's linux-builder listens on the server's loopback; the VM boots on the first connection.
            linuxBuilderSsh = serverName: ''
              Host ${serverName}-linux-builder
                HostName localhost
                Port 31022
                HostKeyAlias ${serverName}-linux-builder
                ProxyJump nix@${serverName}.${domain}
                StrictHostKeyChecking accept-new
                ControlMaster no
                ControlPath none
                ConnectTimeout 30
            '';
          in
          {
            assertions = [
              {
                assertion = roles.server.machines != { };
                message = "@adeci/remote-builder: client has no servers. Add machines to roles.server.";
              }
            ];

            clan.core.vars.generators.${instanceName} = {
              files.id_ed25519 = { };
              files."id_ed25519.pub".secret = false;
              runtimeInputs = [ pkgs.openssh ];
              script = # bash
                ''
                  ssh-keygen -t ed25519 -N "" -C "" -f "$out"/id_ed25519
                '';
            };

            nix.buildMachines = offloadMachines;
            nix.distributedBuilds = offloadMachines != [ ];
            environment.etc."nix/machines-all".text = lib.concatMapStrings (
              machine: machinesFileLine machine + "\n"
            ) buildMachines;

            programs.ssh.extraConfig = lib.mkBefore (
              lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  serverName: server:
                  serverSsh "${serverName}.${domain}"
                  + lib.optionalString (server.settings.linuxBuilder != null) ("\n" + linuxBuilderSsh serverName)
                ) servers
              )
            );
          };
      in
      {
        nixosModule = client;
        darwinModule = client;
      };
  };
}

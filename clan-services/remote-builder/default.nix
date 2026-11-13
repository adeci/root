{ clanLib, ... }:
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
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            # Clients without a public key yet are skipped; servers authorize them on their next deploy.
            clientKeys = lib.filter (key: key != "") (
              lib.mapAttrsToList (
                clientName: _:
                lib.strings.trim (
                  clanLib.getPublicValue {
                    flake = config.clan.core.settings.directory;
                    machine = clientName;
                    generator = instanceName;
                    file = "id_ed25519.pub";
                    default = "";
                  }
                )
              ) (roles.client.machines or { })
            );
          in
          {
            users.users.nix = {
              isSystemUser = true;
              home = "/var/empty";
              group = "nix";
              shell = pkgs.bashInteractive;
              openssh.authorizedKeys.keys = clientKeys ++ settings.externalKeys;
            };
            users.groups.nix = { };

            nix.settings.trusted-users = [ "nix" ];
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

            buildMachines = lib.mapAttrsToList (serverName: server: {
              hostName = "${serverName}.${domain}";
              inherit (server.settings)
                systems
                maxJobs
                speedFactor
                supportedFeatures
                ;
              protocol = "ssh-ng";
              sshUser = "nix";
              sshKey = config.clan.core.vars.generators.${instanceName}.files.id_ed25519.path;
            }) servers;

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
              lib.concatMapStringsSep "\n" (machine: ''
                Host ${machine.hostName}
                  StrictHostKeyChecking accept-new

                # Nix manages its own SSH connections: disable any ControlMaster a user/system ssh config enables for this host.
                # An unreachable builder should fail the build in seconds, not after the TCP timeout.
                Match host ${machine.hostName} user nix
                  ControlMaster no
                  ControlPath none
                  ConnectTimeout 10
              '') buildMachines
            );
          };
      in
      {
        nixosModule = client;
        darwinModule = client;
      };
  };
}

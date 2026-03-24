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
            example = [ "ssh-ed25519 AAAA... aodhan" ];
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
            # Collect public keys from all clan client machines
            clientKeys = lib.mapAttrsToList (
              machineName: _:
              clanLib.getPublicValue {
                flake = config.clan.core.settings.directory;
                machine = machineName;
                generator = "remote-builder-${instanceName}";
                file = "id_ed25519.pub";
              }
            ) (roles.client.machines or { });
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

    perInstance =
      {
        instanceName,
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
            varName = "remote-builder-${instanceName}";
            inherit (config.clan.core.settings) domain;
            dotDomain = if domain != null then ".${domain}" else "";
          in
          {
            clan.core.vars.generators.${varName} = {
              files.id_ed25519 = { };
              files."id_ed25519.pub".secret = false;
              runtimeInputs = [ pkgs.openssh ];
              script = ''
                ssh-keygen -t ed25519 -N "" -f "$out"/id_ed25519
              '';
            };

            nix.buildMachines = map (
              machineName:
              let
                serverSettings = roles.server.machines.${machineName}.settings;
              in
              {
                hostName = "${machineName}${dotDomain}";
                inherit (serverSettings)
                  systems
                  maxJobs
                  speedFactor
                  supportedFeatures
                  ;
                protocol = "ssh-ng";
                sshUser = "nix";
                sshKey = config.clan.core.vars.generators.${varName}.files.id_ed25519.path;
              }
            ) (lib.attrNames roles.server.machines);

            programs.ssh.extraConfig = lib.concatMapStringsSep "\n" (machineName: ''
              Host ${machineName}${dotDomain}
                StrictHostKeyChecking accept-new
            '') (lib.attrNames roles.server.machines);
          };
      };
  };
}

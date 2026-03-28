{ inputs }:
{ clanLib, ... }:
{
  _class = "clan.service";

  manifest = {
    name = "@adeci/harmonia";
    description = "Harmonia binary cache with per-server signing keys";
    categories = [ "System" ];
    readme = builtins.readFile ./README.md;
  };

  roles.server = {
    description = "Harmonia binary cache server that serves the local nix store";

    interface =
      { lib, ... }:
      {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 5000;
            description = "Port for the harmonia cache server";
          };
          address = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override address for clients to reach this server";
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 40;
            description = "Nix substituter priority advertised to clients";
          };
        };
      };

    perInstance =
      {
        instanceName,
        settings,
        ...
      }:
      {
        nixosModule =
          { config, pkgs, ... }:
          let
            inherit (config.clan.core) machineName;
            generatorName = "${instanceName}-${machineName}";
          in
          {
            imports = [ inputs.harmonia.nixosModules.harmonia ];

            # Generate this server's signing keypair (shared pub key, secret private key)
            clan.core.vars.generators.${generatorName} = {
              share = true;
              files.signing-key = {
                secret = true;
                deploy = false;
              };
              files."signing-key.pub".secret = false;
              runtimeInputs = [ pkgs.nix ];
              script = ''
                nix-store --generate-binary-cache-key \
                  ${generatorName} \
                  "$out"/signing-key \
                  "$out"/signing-key.pub
              '';
            };

            # Per-server private copy — only this machine deploys the signing key
            clan.core.vars.generators."${generatorName}-private" = {
              dependencies = [ generatorName ];
              files.signing-key.secret = true;
              script = ''
                cp "$in"/${generatorName}/signing-key "$out"/signing-key
              '';
            };

            services.harmonia-dev.cache = {
              enable = true;
              signKeyPaths = [
                config.clan.core.vars.generators."${generatorName}-private".files.signing-key.path
              ];
              settings.bind = "[::]:${toString settings.port}";
            };

            services.harmonia-dev.daemon.enable = true;
            nix.settings.extra-allowed-users = [ "harmonia" ];
            networking.firewall.allowedTCPPorts = [ settings.port ];
          };
      };
  };

  roles.client = {
    description = "Configures nix to use harmonia cache servers as substituters";

    interface =
      { lib, ... }:
      {
        options.priority = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Override substituter priority (defaults to server's priority)";
        };
      };

    perInstance =
      {
        instanceName,
        roles,
        settings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            lib,
            ...
          }:
          let
            inherit (config.clan.core.settings) domain;
            dotDomain = if domain != null then ".${domain}" else "";
            serverNames = lib.attrNames roles.server.machines;
          in
          {
            nix.settings.substituters = map (
              name:
              let
                serverSettings = roles.server.machines.${name}.settings;
                address = if serverSettings.address != null then serverSettings.address else "${name}${dotDomain}";
                priority = if settings.priority != null then settings.priority else serverSettings.priority;
              in
              "http://${address}:${toString serverSettings.port}?priority=${toString priority}"
            ) serverNames;

            # Read pub keys directly from shared vars — no generator needed on clients
            nix.settings.trusted-public-keys = map (
              name:
              lib.strings.trim (
                clanLib.getPublicValue {
                  flake = config.clan.core.settings.directory;
                  generator = "${instanceName}-${name}";
                  file = "signing-key.pub";
                }
              )
            ) serverNames;
          };
      };
  };
}

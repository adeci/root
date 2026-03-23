{ inputs }:
_:
let
  varsForInstance = instanceName: pkgs: {
    clan.core.vars.generators."harmonia-${instanceName}" = {
      share = true;
      files.signing-key = {
        secret = true;
        deploy = false;
      };
      files."signing-key.pub".secret = false;
      runtimeInputs = [ pkgs.nix ];
      script = ''
        nix-store --generate-binary-cache-key \
          ${instanceName} \
          "$out"/signing-key \
          "$out"/signing-key.pub
      '';
    };
  };
in
{
  _class = "clan.service";

  manifest = {
    name = "@adeci/harmonia";
    description = "Harmonia binary cache with automatic client configuration via clan vars";
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
            description = ''
              Override address for clients to reach this server.
              Defaults to machineName.domain from clan meta.
            '';
          };

          priority = lib.mkOption {
            type = lib.types.int;
            default = 40;
            description = "Default nix substituter priority advertised to clients";
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          { config, pkgs, ... }:
          let
            varName = "harmonia-${instanceName}";
          in
          {
            imports = [
              inputs.harmonia.nixosModules.harmonia
              (varsForInstance instanceName pkgs)
            ];

            # Per-machine copy of the signing key (only deployed to server)
            clan.core.vars.generators."${varName}-signing-key" = {
              dependencies = [ varName ];
              files.signing-key.secret = true;
              script = ''
                cp "$in"/${varName}/signing-key "$out"/signing-key
              '';
            };

            services.harmonia-dev.cache = {
              enable = true;
              signKeyPaths = [
                config.clan.core.vars.generators."${varName}-signing-key".files.signing-key.path
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
          description = "Override substituter priority (defaults to server's priority setting)";
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
            pkgs,
            lib,
            ...
          }:
          let
            inherit (config.clan.core.settings) domain;
            dotDomain = if domain != null then ".${domain}" else "";
          in
          {
            imports = [
              (varsForInstance instanceName pkgs)
            ];

            nix.settings.extra-substituters = map (
              machineName:
              let
                serverSettings = roles.server.machines.${machineName}.settings;
                address =
                  if serverSettings.address != null then serverSettings.address else "${machineName}${dotDomain}";
                priority = if settings.priority != null then settings.priority else serverSettings.priority;
              in
              "http://${address}:${toString serverSettings.port}?priority=${toString priority}"
            ) (lib.attrNames roles.server.machines);

            nix.settings.extra-trusted-public-keys = [
              (lib.strings.trim
                config.clan.core.vars.generators."harmonia-${instanceName}".files."signing-key.pub".value
              )
            ];
          };
      };
  };
}

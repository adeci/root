{
  _class = "clan.service";

  manifest = {
    name = "@adeci/atuin";
    description = "Atuin shell history sync server and logged-in clients";
    categories = [ "Utility" ];
    readme = builtins.readFile ./README.md;
  };

  roles.server = {
    description = "Atuin sync server storing history in PostgreSQL";

    interface =
      { lib, ... }:
      {
        options = {
          port = lib.mkOption {
            type = lib.types.port;
            default = 8888;
            description = "Port for the atuin server";
          };
          address = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override address for clients to reach this server";
          };
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule = {
          clan.core.postgresql.enable = true;
          clan.core.postgresql.databases.atuin = {
            # services.atuin creates the database itself.
            create.enable = false;
            restore.stopOnRestore = [ "atuin" ];
          };

          services.atuin = {
            enable = true;
            openRegistration = false;
            host = "0.0.0.0";
            inherit (settings) port;
          };
        };
      };
  };

  roles.client = {
    description = "Machine whose user is logged in to the server and syncs shell history";

    interface =
      { lib, ... }:
      {
        options.user = lib.mkOption {
          type = lib.types.str;
          description = "User who logs in and owns the account secrets";
          example = "alice";
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
        atuinLogin =
          { config, pkgs }:
          let
            inherit (config.clan.core.vars.generators.${instanceName}) files;
          in
          pkgs.writeShellApplication {
            name = "atuin-login";
            runtimeInputs = [ pkgs.atuin ];
            runtimeEnv = {
              ATUIN_CONFIG_DIR = pkgs.writeTextDir "config.toml" ''
                sync_address = "${config.atuinSync.address}"
              '';
              USERNAME_FILE = files.username.path;
              PASSWORD_FILE = files.password.path;
              KEY_FILE = files.key.path;
            };
            text = builtins.readFile ./login.sh;
          };

        shared =
          { config, lib, ... }:
          let
            serverNames = lib.attrNames roles.server.machines;
            serverName = lib.head serverNames;
            serverSettings = roles.server.machines.${serverName}.settings;
            address =
              if serverSettings.address != null then
                serverSettings.address
              else
                "${serverName}.${config.clan.core.settings.domain}";
          in
          {
            options.atuinSync.address = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              description = "Atuin server this machine syncs shell history with.";
            };

            config = {
              assertions = [
                {
                  assertion = lib.length serverNames == 1;
                  message = "@adeci/atuin: a client syncs with exactly one server, but roles.server has ${toString (lib.length serverNames)}.";
                }
              ];

              atuinSync.address = "http://${address}:${toString serverSettings.port}";

              clan.core.vars.generators.${instanceName} = {
                share = true;
                prompts = lib.genAttrs [ "username" "password" "key" ] (name: {
                  description = "Atuin account ${name}${
                    lib.optionalString (name == "key") " (`atuin key` on a logged-in machine)"
                  }";
                  type = if name == "username" then "line" else "hidden";
                  persist = true;
                });
                files = lib.genAttrs [ "username" "password" "key" ] (_: {
                  owner = settings.user;
                });
              };
            };
          };
      in
      {
        nixosModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            login = atuinLogin { inherit config pkgs; };
          in
          {
            imports = [ shared ];

            systemd.user.services.atuin-login = {
              description = "Atuin sync login";
              wantedBy = [ "default.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe login;
                # The server may not be reachable yet at login.
                Restart = "on-failure";
                RestartSec = 60;
              };
            };
          };

        darwinModule =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            login = atuinLogin { inherit config pkgs; };
          in
          {
            imports = [ shared ];

            launchd.user.agents.atuin-login.serviceConfig = {
              ProgramArguments = [ (lib.getExe login) ];
              RunAtLoad = true;
              # The server may not be reachable yet at login; retry every minute until it is.
              KeepAlive.SuccessfulExit = false;
              ThrottleInterval = 60;
            };
          };
      };
  };
}

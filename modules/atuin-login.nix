let
  session =
    { config, pkgs }:
    let
      files = config.clan.core.vars.generators.atuin.files;
    in
    {
      configDir = pkgs.writeTextDir "config.toml" ''
        sync_address = "${config.wrappers.zsh.atuinSyncAddress}"
      '';

      login = pkgs.writeShellApplication {
        name = "atuin-login";
        runtimeInputs = [ pkgs.atuin ];
        text = ''
          atuin status >/dev/null 2>&1 && exit 0
          atuin login \
            --username "$(<${files.username.path})" \
            --password "$(<${files.password.path})" \
            --key "$(<${files.key.path})"
          atuin sync
        '';
      };
    };

  shared =
    {
      config,
      lib,
      self,
      ...
    }:
    {
      assertions = [
        {
          assertion = config.wrappers.zsh.atuinSyncAddress != null;
          message = "atuin-login needs wrappers.zsh.atuinSyncAddress, the server to log in to.";
        }
      ];

      clan.core.vars.generators.atuin = {
        share = true;
        prompts = lib.genAttrs [ "username" "password" "key" ] (name: {
          description = "Atuin account ${name}${
            lib.optionalString (name == "key") " (`atuin key` on a logged-in machine)"
          }";
          type = if name == "username" then "line" else "hidden";
          persist = true;
        });
        files = lib.genAttrs [ "username" "password" "key" ] (_: {
          owner = self.users.alex.username;
        });
      };
    };
in
{
  nixos =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      inherit (session { inherit config pkgs; }) configDir login;
    in
    {
      imports = [
        self.modules.nixos.wrappers
        shared
      ];

      systemd.user.services.atuin-login = {
        description = "Atuin sync login";
        wantedBy = [ "default.target" ];
        environment.ATUIN_CONFIG_DIR = "${configDir}";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe login;
          # The server may not be reachable yet at login.
          Restart = "on-failure";
          RestartSec = 60;
        };
      };
    };

  darwin =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      inherit (session { inherit config pkgs; }) configDir login;
    in
    {
      imports = [
        self.modules.darwin.wrappers
        shared
      ];

      launchd.user.agents.atuin-login.serviceConfig = {
        ProgramArguments = [ (lib.getExe login) ];
        EnvironmentVariables.ATUIN_CONFIG_DIR = "${configDir}";
        RunAtLoad = true;
        # The server may not be reachable yet at login; retry every minute until it is.
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 60;
      };
    };
}

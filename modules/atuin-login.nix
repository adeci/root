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
      inherit (self.users.alex) username;
      inherit (config.wrappers.zsh) atuinSyncAddress;
      files = config.clan.core.vars.generators.atuin.files;
      configDir = pkgs.writeTextDir "config.toml" ''
        sync_address = "${atuinSyncAddress}"
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
    in
    {
      imports = [ self.modules.nixos.wrappers ];

      assertions = [
        {
          assertion = atuinSyncAddress != null;
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
          owner = username;
        });
      };

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
}

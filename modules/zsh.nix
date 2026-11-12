let
  shared =
    { config, lib, ... }:
    let
      inherit (config.system) primaryUser;
      inherit (config.system.primaryUserProfile) git;
    in
    {
      environment.pathsToLink = [ "/share/zsh" ];

      programs.nix-index-database.comma.enable = true;

      users.users.${primaryUser}.shell = config.wrappers.zsh.wrapper;

      wrappers.zsh = {
        enable = true;
        git = lib.mkIf config.wrappers.git.enable config.wrappers.git.wrapper;
        # Only machines that sync shell history declare atuinSync.
        atuinSyncAddress = lib.mkDefault (config.atuinSync.address or null);
      };
      wrappers.git = {
        enable = true;
        settings.user = {
          name = lib.mkDefault git.name;
          email = lib.mkDefault git.email;
        };
      };
      wrappers.tmux.enable = true;
      wrappers.btop.enable = true;
    };
in
{
  nixos =
    { inputs, self, ... }:
    {
      imports = [
        self.modules.nixos.wrappers
        self.modules.nixos.primary-user
        inputs.nix-index-database.nixosModules.nix-index
        shared
      ];

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        enableGlobalCompInit = false;
        enableLsColors = false;
        promptInit = "";
      };
    };

  darwin =
    {
      config,
      inputs,
      lib,
      self,
      ...
    }:
    {
      imports = [
        self.modules.darwin.wrappers
        self.modules.darwin.primary-user
        inputs.nix-index-database.darwinModules.nix-index
        shared
      ];

      programs.zsh.enable = true;
      environment.shells = lib.mkDefault [ config.wrappers.zsh.wrapper ];
    };
}

{
  nixos =
    {
      config,
      self,
      inputs,
      ...
    }:
    {
      imports = [
        self.modules.nixos.wrappers
        inputs.nix-index-database.nixosModules.nix-index
      ];

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        enableGlobalCompInit = false;
        enableLsColors = false;
        promptInit = "";
      };
      environment.pathsToLink = [ "/share/zsh" ];

      programs.nix-index-database.comma.enable = true;

      # mkUser's default is the unwrapped pkgs.zsh.
      users.users.alex.shell = config.wrappers.zsh.wrapper;

      wrappers.zsh.enable = true;
      wrappers.git.enable = true;
      wrappers.tmux.enable = true;
      wrappers.btop.enable = true;
    };
}

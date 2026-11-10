{
  # Wrapped zsh as the system login shell with all CLI tools baked in.
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

      # nix-index with pre-built database: command-not-found handler + comma
      programs.nix-index-database.comma.enable = true;

      # Override the login shell to our wrapped zsh (mkUser sets pkgs.zsh by default)
      users.users.alex.shell = config.wrappers.zsh.wrapper;

      # Make wrapped tools available system-wide
      wrappers.zsh.enable = true;
      wrappers.git.enable = true;
      wrappers.tmux.enable = true;
      wrappers.btop.enable = true;
    };
}

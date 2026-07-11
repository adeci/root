# Wrapped zsh as the system login shell with all CLI tools baked in.
{
  self,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  zsh = self.wrappers.zsh.wrap { inherit pkgs; };
in
{
  imports = [
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
  users.users.alex.shell = zsh;

  # Make wrapped tools available system-wide
  environment.systemPackages = [
    zsh
    self.packages.${system}.git
    self.packages.${system}.tmux
    self.packages.${system}.btop
  ];
}

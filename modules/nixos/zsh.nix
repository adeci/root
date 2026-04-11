# Wrapped zsh as the system login shell with all CLI tools baked in.
{
  self,
  pkgs,
  inputs,
  ...
}:
let
  zsh = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh.wrap { };
in
{
  imports = [
    inputs.nix-index-database.nixosModules.nix-index
  ];

  programs.zsh.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];

  # nix-index with pre-built database: command-not-found handler + comma
  programs.nix-index-database.comma.enable = true;

  # Override the login shell to our wrapped zsh (mkUser sets pkgs.zsh by default)
  users.users.alex.shell = zsh;

  # Make wrapped tools available system-wide
  environment.systemPackages = [
    zsh
    self.packages.${pkgs.stdenv.hostPlatform.system}.git
    self.packages.${pkgs.stdenv.hostPlatform.system}.tmux
    self.packages.${pkgs.stdenv.hostPlatform.system}.btop
  ];
}

# Wrapped zsh as the system login shell with all CLI tools baked in.
{
  self,
  pkgs,
  ...
}:
let
  wrappedZsh = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh;
in
{
  programs.zsh.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];

  # Override the login shell to our wrapped zsh (mkUser sets pkgs.zsh by default)
  users.users.alex.shell = wrappedZsh;

  # Make wrapped tools available system-wide
  environment.systemPackages = [
    wrappedZsh
    self.packages.${pkgs.stdenv.hostPlatform.system}.git
    self.packages.${pkgs.stdenv.hostPlatform.system}.tmux
    self.packages.${pkgs.stdenv.hostPlatform.system}.btop
  ];
}

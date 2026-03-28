# Wrapped zsh as the system login shell with all CLI tools baked in.
{
  self,
  pkgs,
  ...
}:
let
  zsh = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh.wrap { withLLMTools = true; };
in
{
  programs.zsh.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];

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

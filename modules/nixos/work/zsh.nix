# modules/nixos/zsh.nix without the personal git wrapper
{
  self,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  zsh = self.wrappers.zsh.wrap {
    inherit pkgs;
    git = null;
  };
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

  programs.nix-index-database.comma.enable = true;

  users.users.alex.shell = zsh;

  environment.systemPackages = [
    zsh
    self.packages.${system}.tmux
    self.packages.${system}.btop
  ];
}

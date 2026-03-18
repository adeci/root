{
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    packages.starship
    packages.cheat
    pkgs.python3Packages.argcomplete
  ];
  programs.atuin = {
    enable = true;
    settings = {
      enter_accept = false;
    };
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.direnv = {
    enable = true;
  };
}

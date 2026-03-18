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
    # packages.starship
    packages.cheat
    self.inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli
  ];
  programs.atuin = {
    enable = true;
    settings = {
      enter_accept = false;
      sync_address = "http://sequoia:8888";
      auto_sync = true;
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

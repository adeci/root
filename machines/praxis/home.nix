{ osConfig, pkgs, ... }:
{
  imports = [
    ../../modules/home-manager/profiles/base.nix
    ../../modules/home-manager/profiles/llm-tools.nix
    ../../modules/home-manager/profiles/desktop.nix
    ../../modules/home-manager/rbw.nix
  ];

  home.packages = [ pkgs.bitwarden-desktop ];

  home.stateVersion = osConfig.system.stateVersion;
}

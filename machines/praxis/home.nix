{ osConfig, ... }:
{
  imports = [
    ../../modules/home-manager/profiles/base.nix
    ../../modules/home-manager/profiles/llm-tools.nix
    ../../modules/home-manager/profiles/desktop.nix
    ../../modules/home-manager/rbw.nix
    ../../modules/home-manager/bitwarden.nix
  ];

  home.stateVersion = osConfig.system.stateVersion;
}

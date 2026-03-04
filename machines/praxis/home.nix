{ osConfig, ... }:
{
  imports = [
    ../../modules/home-manager/profiles/base.nix
    ../../modules/home-manager/profiles/llm-tools.nix
    ../../modules/home-manager/profiles/desktop.nix
    ../../modules/home-manager/password-manager.nix
  ];

  home.stateVersion = osConfig.system.stateVersion;
}

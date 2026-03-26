{ osConfig, ... }:
{
  imports = [
    ../../modules/home-manager/profiles/base.nix
    ../../modules/home-manager/profiles/llm-tools.nix
  ];

  home.stateVersion = osConfig.system.stateVersion;
}

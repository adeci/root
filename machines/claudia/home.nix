{ osConfig, ... }:
{
  imports = [
    ../../profiles/home-manager/base.nix
    ../../profiles/home-manager/llm-tools.nix
  ];

  home.stateVersion = osConfig.system.stateVersion;
}

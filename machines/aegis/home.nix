{ osConfig, ... }:
{
  imports = [
    ../../profiles/home-manager/base.nix
    ../../profiles/home-manager/llm-tools.nix
    ../../profiles/home-manager/desktop.nix
  ];

  home.stateVersion = osConfig.system.stateVersion;
}

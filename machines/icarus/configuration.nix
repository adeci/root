{ pkgs, self, ... }:
{
  imports = with self.modules.darwin; [
    self.users.alex.darwinModule

    base
    zsh
    auto-pressure-gc
    desktop
    laptop
    nvim-dev
    librewolf
    llm-config
    llm-tools
    karabiner
    mouse
    aerospace
    secretive
    mac-security
  ];

  networking.hostName = "icarus";
  networking.computerName = "icarus";

  gitSigning.key = "icarus-se";

  environment.systemPackages = [ pkgs.tart ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;
}

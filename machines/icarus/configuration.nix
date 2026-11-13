{ pkgs, self, ... }:
{
  imports = with self.modules.darwin; [
    self.users.alex.darwinModule

    base
    zsh
    auto-pressure-gc
    desktop
    earwig
    laptop
    nvim-dev
    librewolf
    llm-tools
    keyboard
    mouse
    aerospace
    secretive
    mac-security
  ];

  networking.computerName = "icarus";

  gitSigning.key = "icarus-se";

  environment.systemPackages = [ pkgs.tart ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 7;
}

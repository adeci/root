{ self, work, ... }:
{
  imports = with self.modules.darwin; [
    self.users.alex-work.darwinModule

    work.modules.darwin.managed-device
    work.modules.darwin.apps
    work.modules.darwin.shell
    work.modules.darwin.plain-git

    base
    desktop
    nvim-dev
    kagi-search
    keyboard
    mouse
    aerospace
    linux-rosetta-builder
    secretive
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}

{
  self,
  workInputs,
  ...
}:
{
  imports = with self.modules.darwin; [
    self.users.alex-work.darwinModule

    workInputs.self.modules.darwin.managed-device
    workInputs.self.modules.darwin.apps
    workInputs.self.modules.darwin.shell

    base
    desktop
    nvim-dev
    librewolf
    llm-config
    handy
    karabiner
    mouse
    aerospace
    linux-rosetta-builder
    secretive
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}

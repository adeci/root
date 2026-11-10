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
    librewolf
    llm-config
    handy
    karabiner
    mouse
    aerospace
    linux-rosetta-builder
    secretive
  ];

  # Work keys only; Clan deploys as root.
  users.users.root.openssh.authorizedKeys.keys = self.users.alex-work.sshKeys;
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      AuthorizedKeysFile none
    '';
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}

{ self, ... }:
{
  imports = with self.modules.nixos; [ clan-installer ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # shopkey lets work machines install from this stick too.
  users.users.root.openssh.authorizedKeys.keys = self.users.alex.sshKeys ++ [
    (self.users.alex-work.keyNamed "shopkey")
  ];
}

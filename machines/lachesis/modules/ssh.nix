{ lib, self, ... }:
let
  # Only keys on a YubiKey, which need a touch: an agent running as alex on
  # another machine can use the TPM and file keys, and lachesis holds every
  # mandate login.
  touchKeys = lib.filter (lib.hasPrefix "sk-") self.users.alex.sshKeys;
in
{
  services.openssh.settings.PubkeyAcceptedAlgorithms = lib.concatStringsSep "," [
    "sk-ssh-ed25519@openssh.com"
    "sk-ecdsa-sha2-nistp256@openssh.com"
  ];

  users.users.root.openssh.authorizedKeys.keys = lib.mkForce touchKeys;
  users.users.${self.users.alex.username}.openssh.authorizedKeys.keys = lib.mkForce touchKeys;
}

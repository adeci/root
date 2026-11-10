{
  # Graphical LUKS passphrase prompt; the keyring unlocks separately.
  nixos = {
    boot.plymouth.enable = true;
  };
}

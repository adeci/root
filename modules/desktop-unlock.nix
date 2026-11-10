{
  # Graphical LUKS passphrase prompt; the keyring unlocks separately (keyring-tpm).
  nixos = {
    boot.plymouth.enable = true;
  };
}

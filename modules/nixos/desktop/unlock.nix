# Graphical LUKS passphrase prompt; the keyring unlocks separately (./keyring-tpm).
{
  boot.plymouth.enable = true;
  boot.initrd.systemd.enable = true;
}

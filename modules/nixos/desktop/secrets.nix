# GCR's SSH agent can't handle FIDO2 keys.
{ lib, ... }:
{
  services.gnome.gnome-keyring.enable = true;
  services.gnome.gcr-ssh-agent.enable = false;
  programs.ssh.startAgent = lib.mkDefault true;
}

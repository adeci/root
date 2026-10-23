# GCR's SSH agent can't handle FIDO2 keys.
{ lib, ... }:
{
  services.gnome.gnome-keyring.enable = true;
  # Apps store secrets in the login keyring, never in one they create themselves.
  systemd.user.tmpfiles.rules = [
    "d %h/.local/share/keyrings 0700 - - -"
    "f+ %h/.local/share/keyrings/default 0600 - - - login"
  ];
  services.gnome.gcr-ssh-agent.enable = false;
  programs.ssh.startAgent = lib.mkDefault true;
}

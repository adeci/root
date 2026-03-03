_:
{
  programs.ssh.extraConfig = ''
    Host *
      AddKeysToAgent yes
  '';
}

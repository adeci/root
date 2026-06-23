{ self, ... }:
{
  programs.ssh.extraConfig = ''
    Host ringer jonringer
      HostName jonringer.us
      Port 2222
      User ${self.users.alex.username}
      ForwardAgent yes
      StrictHostKeyChecking accept-new
  '';
}

{
  nixos =
    {
      config,
      pkgs,
      self,
      ...
    }:
    let
      username = config.system.primaryUser;
      ssh-tpm-agent = pkgs.ssh-tpm-agent.overrideAttrs {
        doCheck = false; # keyring tests need kernel keyring unavailable in sandbox
      };
    in
    {
      imports = [ self.modules.nixos.primary-user ];

      programs.ssh.startAgent = false;

      security.tpm2.enable = true;
      security.tpm2.tctiEnvironment.enable = true;
      users.users.${username}.extraGroups = [ config.security.tpm2.tssGroup ];

      environment.systemPackages = [
        ssh-tpm-agent
        pkgs.keyutils
      ];

      systemd.user.services.ssh-tpm-agent = {
        description = "SSH TPM Agent";
        unitConfig = {
          ConditionEnvironment = "!SSH_AGENT_PID";
          Requires = "ssh-tpm-agent.socket";
        };
        serviceConfig = {
          ExecStart = "${ssh-tpm-agent}/bin/ssh-tpm-agent";
          PassEnvironment = "SSH_AGENT_PID";
          SuccessExitStatus = 2;
          Type = "simple";
        };
      };

      systemd.user.sockets.ssh-tpm-agent = {
        wantedBy = [ "sockets.target" ];
        description = "SSH TPM Agent Socket";
        socketConfig = {
          ListenStream = "%t/ssh-tpm-agent.sock";
          SocketMode = "0600";
          Service = "ssh-tpm-agent.service";
        };
      };

      environment.sessionVariables = {
        SSH_AUTH_SOCK = "/run/user/${toString config.users.users.${username}.uid}/ssh-tpm-agent.sock";
      };
    };
}

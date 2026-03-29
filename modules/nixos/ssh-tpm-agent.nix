{
  pkgs,
  config,
  ...
}:
let
  ssh-tpm-agent = pkgs.ssh-tpm-agent.overrideAttrs {
    doCheck = false; # keyring tests need kernel keyring unavailable in sandbox
  };
in
{
  # Disable the standard ssh-agent so TPM agent can take over
  programs.ssh.startAgent = false;

  security.tpm2.enable = true;
  security.tpm2.tctiEnvironment.enable = true;
  users.users.alex.extraGroups = [ config.security.tpm2.tssGroup ];

  environment.systemPackages = [
    ssh-tpm-agent
    pkgs.keyutils
  ];

  # TPM SSH agent — socket activated, always available
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

  # Use TPM agent as the default SSH agent
  environment.sessionVariables = {
    SSH_AUTH_SOCK = "/run/user/${toString config.users.users.alex.uid}/ssh-tpm-agent.sock";
  };
}

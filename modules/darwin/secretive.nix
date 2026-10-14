# Secure Enclave SSH keys through Secretive's agent; the darwin counterpart of
# ../nixos/ssh-tpm-agent.nix. Create keys in the Secretive app.
{ config, ... }:
let
  home = config.users.users.${config.system.primaryUser}.home;
  socket = "${home}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
in
{
  homebrew.casks = [ "secretive" ];

  environment.etc."ssh/ssh_config.d/secretive".text = # ssh_config
    ''
      Host *
        IdentityAgent "${socket}"
    '';

  environment.variables.SSH_AUTH_SOCK = socket;
}

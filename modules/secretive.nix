{
  darwin =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      socket = "${config.system.primaryUserHome}/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh";
    in
    {
      imports = [
        self.modules.darwin.primary-user
        self.modules.darwin.git-signing
      ];

      gitSigning.agentSocket = lib.mkDefault socket;

      environment.systemPackages = [ pkgs.secretive ];

      environment.etc."ssh/ssh_config.d/secretive".text = # ssh_config
        ''
          Host *
            IdentityAgent "${socket}"
        '';

      environment.variables.SSH_AUTH_SOCK = socket;
    };
}

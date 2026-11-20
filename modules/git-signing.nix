let
  module =
    class:
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      signing = config.gitSigning;
      profile = config.system.primaryUserProfile;

      # Always sign with the local agent, even when another is forwarded.
      sshKeygen = pkgs.writeShellScript "ssh-keygen-device" ''
        SSH_AUTH_SOCK=${lib.escapeShellArg signing.agentSocket} exec ${pkgs.openssh}/bin/ssh-keygen "$@"
      '';

      allowedSigners = pkgs.writeText "allowed-signers" (
        lib.concatMapStrings (key: ''
          ${profile.git.email} namespaces="git" ${key}
        '') profile.sshKeys
      );
    in
    {
      imports = [
        self.modules.${class}.wrappers
        self.modules.${class}.primary-user
      ];

      options.gitSigning = {
        key = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Comment of the SSH key that signs commits; null for unsigned.";
        };
        agentSocket = lib.mkOption {
          type = lib.types.str;
          description = "SSH agent socket holding that key.";
        };
      };

      config = lib.mkIf (signing.key != null) {
        wrappers.git.settings = {
          user.signingkey = "key::${profile.keyNamed signing.key}";
          gpg = {
            format = "ssh";
            ssh.program = "${sshKeygen}";
            ssh.allowedSignersFile = "${allowedSigners}";
          };
          commit.gpgsign = true;
          tag.gpgsign = true;
        };
      };
    };
in
{
  nixos = module "nixos";
  darwin = module "darwin";
}

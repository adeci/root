let
  shared =
    {
      config,
      lib,
      pkgs,
      self,
      ...
    }:
    let
      cfg = config.gitSigning;
      user = self.users.${config.system.primaryUser};
      keyNamed = comment: lib.head (lib.filter (lib.hasSuffix " ${comment}") user.sshKeys);

      # Signs through this machine's own agent, also in sessions that forward another machine's.
      sshKeygen = pkgs.writeShellScript "ssh-keygen-device" ''
        SSH_AUTH_SOCK=${lib.escapeShellArg cfg.agentSocket} exec ${pkgs.openssh}/bin/ssh-keygen "$@"
      '';

      allowedSigners = pkgs.writeText "allowed-signers" (
        lib.concatMapStrings (key: ''
          ${user.git.email} namespaces="git" ${key}
        '') user.sshKeys
      );
    in
    {
      options.gitSigning = {
        key = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Comment of the primary user's SSH key that signs commits here; null leaves commits unsigned.";
        };
        agentSocket = lib.mkOption {
          type = lib.types.str;
          description = "SSH agent socket holding that key.";
        };
      };

      config = lib.mkIf (cfg.key != null) {
        wrappers.git.settings = {
          user.signingkey = "key::${keyNamed cfg.key}";
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
  nixos =
    { self, ... }:
    {
      imports = [
        self.modules.nixos.wrappers
        self.modules.nixos.primary-user
        shared
      ];
    };

  darwin =
    { self, ... }:
    {
      imports = [
        self.modules.darwin.wrappers
        shared
      ];
    };
}

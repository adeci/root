{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.ssh;
in
{
  options.adeci.ssh.enable = lib.mkEnableOption "SSH client configuration";
  config = lib.mkIf cfg.enable {
    programs.ssh.extraConfig = ''
      Host *
        AddKeysToAgent yes
    '';
  };
}

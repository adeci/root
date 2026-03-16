{ pkgs, ... }:
{
  # Bitwarden Desktop — imperative settings to configure per device:
  #   Security:
  #     Vault timeout: On system lock
  #     Timeout action: Lock
  #   Preferences:
  #     Show tray icon: on
  #     Close to tray icon: on
  #     Start to tray icon: on
  #     Start automatically on login: on
  #   SSH:
  #     Enable SSH agent: on
  #     Ask for authorization: Remember until vault is locked
  home.packages = [ pkgs.bitwarden-desktop ];

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."local-agent" = {
      match = ''exec "test -z $SSH_CONNECTION"'';
      addKeysToAgent = "yes";
      extraOptions.IdentityAgent = "~/.bitwarden-ssh-agent.sock";
    };
  };
}

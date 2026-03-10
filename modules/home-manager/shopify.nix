{ config, lib, ... }:
{
  # SSH via 1Password agent (no private key on disk, Touch ID to approve)
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      addKeysToAgent = "yes";
      extraOptions = {
        "IdentityAgent" =
          ''"${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"'';
      };
    };
  };
  programs.fish.interactiveShellInit = lib.mkOrder 1100 ''
    # Shopify tec (includes shadowenv, dev tools, wish, and shell hooks)
    if test -x $HOME/.local/state/tec/profiles/base/current/global/init
      $HOME/.local/state/tec/profiles/base/current/global/init fish | source
    end
  '';
  # Disable wish aliases (cd→wcd, ls→wls, j→wj) to avoid
  # conflicts with zoxide and missing fish completions
  xdg.configFile."wish.fish.toml".text = ''
    [features]
    "alias.cd" = false
    "alias.j" = false
    "alias.ls" = false
    wcd = true
    worldjump = true
    worldpath = false
  '';
  programs.fish.shellAliases = {
    claude = "devx claude";
    pi = "devx pi";
  };
}

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
  programs.zsh.initContent = lib.mkOrder 1100 ''
    # Shopify tec (includes shadowenv, dev tools, wish, and shell hooks)
    if [[ -x "$HOME/.local/state/tec/profiles/base/current/global/init" ]]; then
      eval "$($HOME/.local/state/tec/profiles/base/current/global/init zsh)"
    fi
  '';
  # Disable wish aliases (cd→wcd, ls→wls, j→wj) to avoid
  # conflicts with zoxide
  xdg.configFile."wish.zsh.toml".text = ''
    [features]
    "alias.cd" = false
    "alias.j" = false
    "alias.ls" = false
    wcd = true
    worldjump = true
    worldpath = false
  '';
  programs.zsh.shellAliases = {
    claude = "devx claude";
    pi = "devx pi";
  };
}

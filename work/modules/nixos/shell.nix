{ pkgs, ... }:
let
  # Disable WISH aliases (cd->wcd, ls->wls, j->wj)
  wishConfig = (pkgs.formats.toml { }).generate "wish.zsh.toml" {
    features = {
      "alias.cd" = false;
      "alias.j" = false;
      "alias.ls" = false;
      wcd = true;
      worldjump = true;
      worldpath = false;
    };
  };
in
{
  programs.zsh.interactiveShellInit = # zsh
    ''
      # shopify clusters to local kubernetes config
      export KUBECONFIG="''${KUBECONFIG:+$KUBECONFIG:}$HOME/.kube/config:$HOME/.kube/config.shopify.cloudplatform"

      # Shopify tec (includes shadowenv, dev tools, wish, and shell hooks)
      if [[ -x "$HOME/.local/state/tec/profiles/base/current/global/init" ]]; then
        eval "$($HOME/.local/state/tec/profiles/base/current/global/init zsh)"
      fi
    '';

  systemd.user.tmpfiles.rules = [ "L+ %h/.config/wish.zsh.toml - - - - ${wishConfig}" ];
}

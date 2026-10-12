{
  self,
  pkgs,
  ...
}:
let
  shopifyZsh = self.wrappers.zsh.wrap {
    inherit pkgs;
    extraInit = # zsh
      ''
        if [[ -f /opt/homebrew/share/google-cloud-sdk/path.zsh.inc ]]; then
          source /opt/homebrew/share/google-cloud-sdk/path.zsh.inc
        fi

        # shopify clusters to local kubernetes config
        export KUBECONFIG="''${KUBECONFIG:+$KUBECONFIG:}$HOME/.kube/config:$HOME/.kube/config.shopify.cloudplatform"

        # Shopify tec (includes shadowenv, dev tools, wish, and shell hooks)
        if [[ -x "$HOME/.local/state/tec/profiles/base/current/global/init" ]]; then
          eval "$($HOME/.local/state/tec/profiles/base/current/global/init zsh)"
        fi
      '';
  };
in
{
  # Replace default zsh with shopify variant
  environment.shells = [ shopifyZsh ];
  environment.systemPackages = [ shopifyZsh ];
  # Disable WISH aliases (cd->wcd, ls->wls, j->wj)
  system.activationScripts.postActivation.text = # bash
    ''
      mkdir -p /Users/alex/.config
      cat > /Users/alex/.config/wish.zsh.toml << 'EOF'
      [features]
      "alias.cd" = false
      "alias.j" = false
      "alias.ls" = false
      wcd = true
      worldjump = true
      worldpath = false
      EOF
      chown alex:staff /Users/alex/.config/wish.zsh.toml
    '';
}

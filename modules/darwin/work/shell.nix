{
  self,
  pkgs,
  lib,
  ...
}:
let
  shopifyZsh = self.wrappers.zsh.wrap {
    inherit pkgs;
    git = null;
    extraInit = # zsh
      ''
        if [[ -f /opt/homebrew/share/google-cloud-sdk/path.zsh.inc ]]; then
          source /opt/homebrew/share/google-cloud-sdk/path.zsh.inc
        fi

        export KUBECONFIG="''${KUBECONFIG:+$KUBECONFIG:}$HOME/.kube/config:$HOME/.kube/config.shopify.cloudplatform"

        # Work toolchain shell hooks
        if [[ -x "$HOME/.local/state/tec/profiles/base/current/global/init" ]]; then
          eval "$($HOME/.local/state/tec/profiles/base/current/global/init zsh)"
        fi

        # No environment banner before each prompt
        if (( $+functions[__shadowenv_hook] )); then
          functions -c __shadowenv_hook __shadowenv_hook_verbose
          __shadowenv_hook() { __shadowenv_hook_verbose preexec; }
        fi
      '';
  };
in
{
  # Win sw/bin over base's personal zsh and git
  environment.shells = [ shopifyZsh ];
  environment.systemPackages = [
    (lib.hiPrio shopifyZsh)
    (lib.hiPrio pkgs.git)
  ];
  # Keep cd, ls and j unaliased
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

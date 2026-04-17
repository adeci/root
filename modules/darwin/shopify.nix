{
  self,
  pkgs,
  lib,
  ...
}:
let
  shopifyZsh = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh.wrap {
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

  nix.extraOptions = ''
    !include nix.conf.d/shopify.conf
  '';

  # move aside any externally-managed nix.custom.conf so nix-darwin's sha256 check doesn't abort
  system.activationScripts.checks.text = lib.mkBefore ''
    if [[ -e /etc/nix/nix.custom.conf ]] \
        && /usr/bin/grep -q '^!include' /etc/nix/nix.custom.conf; then
      /bin/mv /etc/nix/nix.custom.conf /etc/nix/nix.custom.conf.bak
    fi
  '';

  homebrew = {
    taps = [
      "homebrew/core"
      "homebrew/cask"
    ];
    casks = [
      "1password"
      "1password-cli"
      "gcloud-cli"
      "slack"
    ];
  };

  # 1Password SSH agent
  environment.etc."ssh/ssh_config.d/shopify".text = # ssh_config
    ''
      Host *
        AddKeysToAgent yes
        IdentityAgent "/Users/alex/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    '';

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

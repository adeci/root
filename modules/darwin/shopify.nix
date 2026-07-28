{
  self,
  pkgs,
  lib,
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
  # Shopify's Determinate installation owns the Nix daemon and its configuration.
  nix.enable = lib.mkForce false;

  # Provider integration inherited by isolated personal Pi subagents.
  environment.variables.PI_SUBAGENT_BOOTSTRAP_EXTENSIONS = "/Users/alex/.pi/agent/extensions/shopify-proxy";

  # Preserve Homebrew packages and taps managed by Shopify tooling.
  homebrew.onActivation.cleanup = lib.mkForce "none";

  # Replace default zsh with shopify variant
  environment.shells = [ shopifyZsh ];
  environment.systemPackages = [
    shopifyZsh
    self.packages.${pkgs.stdenv.hostPlatform.system}.handy
  ];

  homebrew = {
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

# Shopify work environment — 1Password SSH, tec/shadowenv, homebrew casks.
{
  self,
  pkgs,
  ...
}:
let
  shopifyZsh = self.packages.${pkgs.stdenv.hostPlatform.system}.zsh.wrap {
    extraInit = # zsh
      ''
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

_: {
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

  # 1Password ssh agent
  environment.etc."ssh/ssh_config.d/shopify".text = ''
    Host *
      AddKeysToAgent yes
      IdentityAgent "/Users/alex/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  '';

  # Disable WISH aliases (cd->wcd, ls->wls, j->wj)
  system.activationScripts.postActivation.text = ''
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

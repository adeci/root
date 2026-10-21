{ pkgs, self, ... }:
let
  # Keep cd, ls and j unaliased
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

  gitConfig = (pkgs.formats.gitIni { }).generate "git-config" {
    user = {
      name = "Alex Decious";
      inherit (self.users.alex-work) email;
    };
    init.defaultBranch = "main";
    pull.rebase = true;
    push.autoSetupRemote = true;
  };
in
{
  programs.zsh.interactiveShellInit = # zsh
    ''
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

  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/wish.zsh.toml - - - - ${wishConfig}"
    "d %h/.config/git 0755 - - -"
    "L+ %h/.config/git/config - - - - ${gitConfig}"
  ];
}

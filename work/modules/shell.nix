let
  shared =
    { config, pkgs, ... }:
    {
      home.links = {
        ".config/wish.zsh.toml" = (pkgs.formats.toml { }).generate "wish.zsh.toml" {
          features = {
            "alias.cd" = false;
            "alias.j" = false;
            "alias.ls" = false;
            wcd = true;
            worldjump = true;
            worldpath = false;
          };
        };

        # The plain git gets the git wrapper's settings.
        ".config/git/config" = (pkgs.formats.gitIni { }).generate "git-config" config.wrappers.git.settings;
      };

      wrappers.zsh.extraInit = # zsh
        ''
          export KUBECONFIG="''${KUBECONFIG:+$KUBECONFIG:}$HOME/.kube/config:$HOME/.kube/config.shopify.cloudplatform"

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
  nixos =
    { self, ... }:
    {
      imports = [
        self.modules.nixos.home-links
        self.modules.nixos.primary-user
        self.modules.nixos.wrappers
        shared
      ];
    };

  darwin =
    { self, ... }:
    {
      imports = [
        self.modules.darwin.home-links
        self.modules.darwin.primary-user
        self.modules.darwin.wrappers
        shared
      ];
    };
}

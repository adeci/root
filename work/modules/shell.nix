let
  shared =
    { pkgs, self, ... }:
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

        ".config/git/config" = (pkgs.formats.gitIni { }).generate "git-config" {
          user = { inherit (self.users.alex-work.git) name email; };
          init.defaultBranch = "main";
          pull.rebase = true;
          push.autoSetupRemote = true;
        };
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
        self.modules.nixos.wrappers
        shared
      ];
    };

  darwin =
    { self, ... }:
    {
      imports = [
        self.modules.darwin.home-links
        self.modules.darwin.wrappers
        shared
      ];
    };
}

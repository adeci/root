{ config, lib, ... }:
let
  cfg = config.adeci.shopify;
in
{
  options.adeci.shopify.enable = lib.mkEnableOption "Shopify-specific shell configuration";
  config = lib.mkIf cfg.enable {
    programs.fish.interactiveShellInit = lib.mkOrder 1100 ''
      # Shopify tec (includes shadowenv, dev tools, wish, and shell hooks)
      if test -x $HOME/.local/state/tec/profiles/base/current/global/init
        $HOME/.local/state/tec/profiles/base/current/global/init fish | source
      end
    '';
    programs.fish.shellAliases = {
      claude = "devx claude";
      pi = "devx pi";
    };
  };
}

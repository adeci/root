{ wlib, pkgs, ... }:
{
  imports = [ wlib.modules.default ];

  config = {
    package = pkgs.herdr;

    # Config only (state stays in ~/.config/herdr); the spawned server inherits it.
    env.HERDR_CONFIG_PATH = "${./config.toml}";

    # For the lazygit popup in config.toml.
    runtimePkgs = [ pkgs.lazygit ];
  };
}

{ wlib, pkgs, ... }:
{
  imports = [ wlib.modules.default ];

  config = {
    package = pkgs.herdr;

    # Only the config moves (session.json, logs and sockets stay in ~/.config/herdr); the client-spawned server inherits this.
    env.HERDR_CONFIG_PATH = "${./config.toml}";

    # For the lazygit popup in config.toml.
    runtimePkgs = [ pkgs.lazygit ];
  };
}

{
  wlib,
  pkgs,
  ...
}:
{
  imports = [ wlib.modules.default ];

  package = pkgs.herdr;

  # Only the config moves; herdr keeps session.json, logs and sockets in
  # ~/.config/herdr. The server is spawned by the client and inherits this.
  env.HERDR_CONFIG_PATH = "${./config.toml}";

  # For the lazygit popup in config.toml.
  runtimePkgs = [ pkgs.lazygit ];
}

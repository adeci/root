{
  config,
  wlib,
  pkgs,
  ...
}:
{
  imports = [
    wlib.modules.default
    ../thaw/wrapper.nix
  ];

  package = pkgs.herdr;
  thaw.files."config.toml" = ./config.toml;
  # Re-reads config in the server and attached clients; panes keep running.
  # Fails (and does nothing) when no server is up.
  thaw.reload = "herdr server reload-config >/dev/null";

  # Only the config moves; herdr keeps session.json, logs and sockets in
  # ~/.config/herdr. The server is spawned by the client and inherits this.
  runShell = [
    ''export HERDR_CONFIG_PATH="${config.thaw.dir}/config.toml"''
  ];
}

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
  thaw.reload = "herdr status server >/dev/null 2>&1 && herdr server reload-config";

  # Only the config moves; herdr keeps session.json, logs and sockets in
  # ~/.config/herdr. The server is spawned by the client and inherits this.
  runShell = [
    ''export HERDR_CONFIG_PATH="${config.thaw.dir}/config.toml"''
  ];
}

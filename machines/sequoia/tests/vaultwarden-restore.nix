{
  inputs,
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;

  resticClient = (import ../../../clan-services/restic).roles.client;

  # The settings clan hands the role: checked against its interface, with its defaults.
  resticSettings =
    (lib.evalModules {
      modules = [
        resticClient.interface
        {
          # A local folder rather than object storage, so the test needs no network.
          repositoryBase = "/var/lib/restic";
          credentials = {
            generator = "restic-credentials";
            file = "env";
          };
        }
      ];
    }).config;
in
pkgs.testers.runNixOSTest {
  name = "sequoia-vaultwarden-restore";
  node.specialArgs = { inherit self inputs; };

  nodes.sequoia = {
    imports = [
      ../../../flake/tests/clan-stand-in.nix
      (resticClient.perInstance { settings = resticSettings; }).nixosModule
      ../modules/vaultwarden
    ];

    # The real file is set with clan vars set, so nothing generates it; a local repository needs no credentials.
    clan.core.vars.generators.restic-credentials.script = ''touch "$out/env"'';
  };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.sequoia.clan.core) backups state vars;
      inherit (nodes.sequoia.services) vaultwarden;
    in
    ''
      port = ${toString vaultwarden.config.ROCKET_PORT}
      admin_token = "${vars.generators.vaultwarden.files.admin_token_plaintext.path}"
      data_dir = "/var/lib/${nodes.sequoia.systemd.services.vaultwarden.serviceConfig.StateDirectory}"
      folders = ${builtins.toJSON state.vaultwarden.folders}
      timer = "restic-backups-${resticSettings.jobName}.timer"
      list_backups = "${backups.providers.restic.list}"
      pre_restore = "${state.vaultwarden.preRestoreCommand}"
      restore = "${backups.providers.restic.restore}"
      post_restore = "${state.vaultwarden.postRestoreCommand}"
    ''
    + builtins.readFile ./vaultwarden-restore.py;
}

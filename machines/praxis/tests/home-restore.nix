{
  inputs,
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;

  resticClient = (import ../../../clan-services/restic).roles.client;

  # praxis's settings from the inventory, the exclude list every client shares among them, checked against the role's interface.
  resticSettings =
    (lib.evalModules {
      modules = [
        resticClient.interface
        self.inventory.clanInstances.restic.roles.client.settings
        self.inventory.clanInstances.restic.roles.client.machines.praxis.settings
        {
          # A local folder rather than object storage, so the test needs no network.
          repositoryBase = lib.mkForce "/var/lib/restic";
          credentials = lib.mkForce {
            generator = "restic-credentials";
            file = "env";
          };
        }
      ];
    }).config;
in
pkgs.testers.runNixOSTest {
  name = "praxis-home-restore";
  node.specialArgs = { inherit self inputs; };

  nodes.praxis = {
    imports = [
      ../../../flake/tests/clan-stand-in.nix
      (resticClient.perInstance { settings = resticSettings; }).nixosModule
    ];

    # As praxis's configuration declares it.
    clan.core.state.home.folders = [ "/home/alex" ];
    users.users.alex.isNormalUser = true;

    # The real file is set with clan vars set, so nothing generates it; a local repository needs no credentials.
    clan.core.vars.generators.restic-credentials.script = ''touch "$out/env"'';

    # The hourly try asks NetworkManager whether the network is metered.
    networking.networkmanager.enable = true;
    virtualisation.vlans = [ ];

    # What systemd-suspend.service needs before it suspends, without suspending the VM.
    systemd.services.test-sleep = {
      requires = [ "sleep.target" ];
      after = [ "sleep.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.coreutils}/bin/true";
      };
    };

    environment.systemPackages = [
      pkgs.git
      pkgs.jq
    ];
  };

  testScript =
    { nodes, ... }:
    let
      inherit (nodes.praxis.clan.core) backups state;
    in
    ''
      home = "${lib.head state.home.folders}"
      job = "${resticSettings.jobName}"
      repository = "${nodes.praxis.services.restic.backups.${resticSettings.jobName}.repository}"
      list_backups = "${backups.providers.restic.list}"
      restore = "${backups.providers.restic.restore}"
    ''
    + builtins.readFile ./home-restore.py;
}

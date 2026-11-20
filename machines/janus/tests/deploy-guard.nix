{
  inputs,
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;
  inherit (self.inventory) lan router;
  inherit (self.inventory.routeros) exporter;
  sshKeys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
  clan-cli = self.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli;
  # The option clan-cli's patch reads to tell if a machine waits for confirmation.
  guardPath = builtins.match ''.*machine\.select\("config\.\?([^"]*)"\).*'' (
    builtins.readFile ../../../packages/clan-cli/confirm-switch.patch
  );

  # One network per cable; the WAN leads nowhere, like an ISP outage.
  cables = {
    wan = 1;
    lan = 2;
    mgmt = 3;
  };

  # Take the lease's address, default route and DNS server.
  udhcpcScript = pkgs.writeShellScript "udhcpc-script" ''
    [ "$1" = bound ] || exit 0
    ip address add "$ip/$mask" dev "$interface"
    ip route add default via "$router"
    echo "nameserver $dns" > "/etc/netns/$(ip netns identify)/resolv.conf"
  '';
in
# Without it clan skips the confirmation and janus reverts after every deploy.
assert
  guardPath != null
  && lib.hasAttrByPath (lib.splitString ".?" (builtins.head guardPath)) self.nixosConfigurations.janus.config;
pkgs.testers.runNixOSTest {
  name = "janus-deploy-guard";
  node.specialArgs = { inherit self inputs; };

  nodes.janus =
    { lib, pkgs, ... }:
    {
      imports = [
        ../../../flake/tests/clan-stand-in.nix
        # Declares the monitoring options the router modules read.
        (import ../../../clan-services/monitoring).perMachine.nixosModule
        ../modules/router
        ../modules/deploy-guard
      ];

      virtualisation.interfaces = {
        ${router.interfaces.wan}.vlan = cables.wan;
        ${router.interfaces.lan}.vlan = cables.lan;
        ${router.interfaces.mgmt}.vlan = cables.mgmt;
      };

      # As clan-core sets it on janus; the test's stand-in for clan leaves it on.
      systemd.network.wait-online.enable = false;

      # Boot as janus does (ext4-single-disk.nix), so GRUB shows a revert's default.
      virtualisation.useBootLoader = true;
      virtualisation.useEFIBoot = true;
      boot.loader.grub = {
        efiSupport = true;
        efiInstallAsRemovable = true;
        device = "nodev";
      };

      monitoring.exporters = (import ../monitoring self.inventory).exporters;
      clan.core.vars.generators.${exporter.generator}.script = ''touch "$out/${exporter.file}"'';
      services.openssh.enable = true;
      users.users.root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilPublicKey ];

      deployGuard.window = lib.mkForce 45;
      # Fails before every switch, as a check of the internet would during an ISP outage.
      deployGuard.checks.upstream = "${lib.getExe' pkgs.iputils "ping"} -c 1 -W 2 192.0.2.1";

      # Stopping it kills the switch, as a dropped ssh session kills clan's switch midway (clan #8245).
      systemd.services.switch-killer = {
        wantedBy = [ "multi-user.target" ];
        environment.SWITCH = "any";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe' pkgs.coreutils "true";
          ExecStop = "${lib.getExe' pkgs.procps "pkill"} -KILL -f 'bin/switch-to-configuration switch'";
        };
      };

      # The systems janus is switched to; specialisations keep its name and addresses.
      specialisation = {
        harmless.configuration = {
          environment.etc.deploy-guard-test.text = "harmless";
          # Refuse switching while the file exists, as a pre-switch check like home-links can.
          system.preSwitchChecks.refuseWhileMarked = "test ! -e /run/deploy-guard-test-refuse";
        };
        closesSsh.configuration.services.openssh.ports = [ 2222 ];
        # Kea keeps running and serves no one.
        breaksDhcp.configuration.services.kea.dhcp4.settings.subnet4 = lib.mkForce [ ];
        # Unbound keeps running and answers only janus itself.
        breaksDns.configuration.services.unbound.settings.server.interface = lib.mkForce [ "127.0.0.1" ];
        # Both change, so the switch stops both and dies with Kea down.
        diesMidSwitch.configuration.systemd.services = {
          switch-killer.environment.SWITCH = lib.mkForce "dies";
          kea-dhcp4-server.environment.SWITCH = "dies";
        };
        # Its switch starts a unit that runs longer than the window.
        outlastsWindow.configuration.systemd.services.slow-start = {
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe' pkgs.coreutils "sleep"} 70";
          };
        };
      };
    };

  # The switch and its hosts, one netns per host.
  nodes.clients = {
    virtualisation.interfaces = {
      trunk.vlan = cables.lan;
      mgmt.vlan = cables.mgmt;
    };
    networking.useDHCP = false;
    environment.systemPackages = [ pkgs.dnsutils ];
    systemd.tmpfiles.rules = [
      "C /root/.ssh/id_snakeoil 0600 root root - ${sshKeys.snakeOilPrivateKey}"
    ];
  };

  testScript =
    { nodes, ... }:
    ''
      inventory_json = ${builtins.toJSON (builtins.toJSON { inherit lan; })}
      window = ${toString nodes.janus.deployGuard.window}
      lease_check = "${nodes.janus.deployGuard.checks.lease}"
      metrics_file = "${nodes.janus.monitoring.textfileDirectory}/deploy-guard.prom"
      busybox = "${lib.getExe pkgs.busybox}"
      udhcpc_script = "${udhcpcScript}"
      # The patched clan-cli's own functions, on the Python it runs on.
      clan_python = "${clan-cli.pythonRuntime.withPackages (ps: [ ps.argcomplete ])}/bin/python3"
      clan_lib = "${clan-cli}/${clan-cli.pythonRuntime.sitePackages}"
      clan_switch_script = "${./clan-switch.py}"
    ''
    + builtins.readFile ./deploy-guard.py;
}

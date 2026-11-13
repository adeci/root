{
  inputs,
  pkgs,
  self,
}:
let
  inherit (pkgs) lib;
  inherit (self.inventory.lan) hosts;
  inherit (self.inventory.lan.vlans) tenant;
  sshKeys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;

  seats = [
    "scylla"
    "charybdis"
  ];
  devices = {
    scylla = "0000:00:10.0";
    charybdis = "0000:00:11.0";
  };

  secrets = pkgs.runCommand "leviathan-microvms-secrets" { nativeBuildInputs = [ pkgs.openssh ]; } ''
    mkdir $out
    for seat in ${lib.escapeShellArgs seats}; do
      ssh-keygen -q -t ed25519 -N "" -C "$seat" -f "$out/$seat"
    done
    echo tskey-fixture > $out/tailscale-gaming
  '';
in
pkgs.testers.runNixOSTest {
  name = "leviathan-microvms";
  globalTimeout = 2400;
  node.specialArgs = { inherit self inputs; };

  nodes.janus =
    { lib, pkgs, ... }:
    {
      virtualisation.vlans = [
        1
        2
      ];
      environment.systemPackages = [ pkgs.wakeonlan ];
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = tenant.gateway;
          prefixLength = 24;
        }
      ];
      networking.firewall.allowedUDPPorts = [ 67 ];
      services.dnsmasq = {
        enable = true;
        settings = {
          interface = "eth1";
          bind-interfaces = true;
          port = 0;
          dhcp-range = "${tenant.dhcpPool.start},${tenant.dhcpPool.end},1h";
          dhcp-host = map (name: "${hosts.${name}.mac},${hosts.${name}.ip}") seats;
        };
      };
      systemd.tmpfiles.rules = [
        "C /root/.ssh/id_snakeoil 0600 root root - ${sshKeys.snakeOilPrivateKey}"
        "L+ /root/secrets - - - - ${secrets}"
      ];
    };

  nodes.leviathan =
    { lib, ... }:
    {
      imports = [ ../modules/microvms.nix ];

      virtualisation = {
        # 1: tenant VLAN, 2: trusted LAN
        vlans = [
          1
          2
        ];
        cores = 4;
        memorySize = 8192;
        diskSize = 12288;
        # e1000e NICs behind a virtual IOMMU stand in for the GPUs.
        qemu.options = [
          "-machine q35,kernel-irqchip=split"
          "-device intel-iommu,intremap=on,caching-mode=on"
          "-device e1000e,bus=pcie.0,addr=0x10"
          "-device e1000e,bus=pcie.0,addr=0x11"
        ];
      };
      boot.kernelParams = [ "intel_iommu=on" ];
      networking.useNetworkd = true;
      systemd.network.networks."10-tenant-uplink".matchConfig.Name = lib.mkForce "eth1";

      microvmHost = {
        vms = lib.genAttrs seats (name: {
          gpu = lib.mkForce devices.${name};
          cpus = lib.mkForce null;
          vcpu = lib.mkForce 1;
          memoryMiB = lib.mkForce 1536;
          config =
            { lib, ... }:
            {
              gamingSeat.idleMinutes = 1;
              services.moonshine.enable = lib.mkForce false;
              services.tailscale.enable = lib.mkForce false;
              # Moonshine keeps the gamer's manager up on a real seat.
              users.users.gamer.linger = true;
              users.users.root.openssh.authorizedKeys.keys = [ sshKeys.snakeOilPublicKey ];
            };
        });
        secretFiles = lib.genAttrs seats (name: {
          ssh-host-key = "${secrets}/${name}";
          tailscale-gaming = "${secrets}/tailscale-gaming";
        });
        gpu = {
          hostDriver = "e1000e";
          holders = lib.mkForce [ "fake-gpu-holder.service" ];
        };
        wakeOnLan = lib.mkForce [ "eth2" ];
      };

      systemd.services.fake-gpu-holder = {
        wantedBy = [ "multi-user.target" ];
        script = ''
          for dev in ${toString (lib.attrValues devices)}; do
            printf '%s ' "$(basename "$(readlink /sys/bus/pci/devices/$dev/driver || echo none)")"
          done >> /run/holder-saw
          echo >> /run/holder-saw
          exec sleep infinity
        '';
      };
    };

  testScript = ''
    seats = ${builtins.toJSON seats}
    devices = ${builtins.toJSON devices}
    ips = ${builtins.toJSON (lib.genAttrs seats (name: hosts.${name}.ip))}
    macs = ${builtins.toJSON (lib.genAttrs seats (name: hosts.${name}.mac))}
    tenant_gateway = "${tenant.gateway}"
    tenant_broadcast = "${tenant.prefix}.255"
  ''
  + builtins.readFile ./microvms.py;
}

{
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory.lan) domain hosts vlans;

  # What the client does with its lease: takes the address, and prints the resolver the lease names.
  onLease = pkgs.writeShellScript "janus-lease-check-bound" ''
    [ "$1" = bound ] || exit 0
    ${lib.getExe' pkgs.iproute2 "ip"} address add "$ip/$mask" dev "$interface"
    echo "$dns"
  '';

  leaseCheck = pkgs.writeShellApplication {
    name = "janus-lease-check";
    runtimeInputs = [
      pkgs.dnsutils
      pkgs.iproute2
    ];
    runtimeEnv = {
      BUSYBOX = lib.getExe pkgs.busybox;
      ON_LEASE = onLease;
      # The mgmt VLAN is janus's one bridge, so a client on janus itself can join it.
      BRIDGE = vlans.mgmt.interface;
      # Locally administered, so no device has it; with it, every check reuses one lease.
      MAC = "02:00:00:99:00:01";
      CLIENT_NAME = "janus-deploy-guard";
      # A name Unbound answers from the inventory, so the check needs nothing beyond janus.
      NAME = "nexus.${domain}";
      ADDRESS = hosts.nexus.ip;
    };
    text = builtins.readFile ./lease-check.sh;
  };
in
{
  imports = [ self.modules.nixos.deploy-guard ];

  deployGuard = {
    window = 3 * 60;
    checks = {
      dhcp = "systemctl is-active --quiet kea-dhcp4-server.service";
      dns = "systemctl is-active --quiet unbound.service";
      firewall = "systemctl is-active --quiet nftables.service";
      lease = lib.getExe leaseCheck;
    };
  };
}

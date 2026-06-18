{
  lib,
  self,
  ...
}:
let
  topology = import ./topology.nix { inherit lib self; };
in
{
  networking.networkmanager.enable = false;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  hardware.facter.detected.dhcp.enable = false;

  systemd.network.enable = true;
  systemd.network.netdevs =
    lib.mapAttrs' (
      _: vlan:
      lib.nameValuePair "20-${topology.vlanInterface vlan}" {
        netdevConfig = {
          Name = topology.vlanInterface vlan;
          Kind = "vlan";
        };
        vlanConfig.Id = vlan.id;
      }
    ) topology.vlans
    // {
      "10-br-mgmt".netdevConfig = {
        Name = "br-mgmt";
        Kind = "bridge";
      };
    };

  systemd.network.networks = {
    "10-wan" = {
      matchConfig.Name = topology.wan;
      networkConfig = topology.noIpv6 // {
        DHCP = "ipv4";
      };
      dhcpV4Config.UseDNS = false;
    };

    "20-lan" = {
      matchConfig.Name = topology.lan;
      linkConfig.RequiredForOnline = "carrier";
      networkConfig = topology.noIpv6 // {
        VLAN = topology.trunkVlanInterfaces;
      };
    };

    "20-mgmt" = {
      matchConfig.Name = topology.mgmt;
      linkConfig.RequiredForOnline = "no";
      networkConfig = topology.noIpv6 // {
        Bridge = "br-mgmt";
      };
    };

    "20-vlan99-bridge" = {
      matchConfig.Name = topology.vlanInterface topology.vlans.mgmt;
      linkConfig.RequiredForOnline = "no";
      networkConfig = topology.noIpv6 // {
        Bridge = "br-mgmt";
      };
    };

    "30-br-mgmt" = {
      matchConfig.Name = "br-mgmt";
      address = [ "${topology.vlans.mgmt.gateway}/24" ];
      linkConfig.RequiredForOnline = "no";
      networkConfig = topology.noIpv6;
    };
  }
  // lib.mapAttrs' (
    _name: vlan:
    lib.nameValuePair "30-${topology.vlanInterface vlan}" {
      matchConfig.Name = topology.vlanInterface vlan;
      address = [ "${vlan.gateway}/24" ];
      linkConfig.RequiredForOnline = "no";
      networkConfig = topology.noIpv6;
    }
  ) topology.routedVlans
  // lib.listToAttrs (
    map (interface: {
      name = "90-spare-${interface}";
      value = {
        matchConfig.Name = interface;
        linkConfig.RequiredForOnline = "no";
        networkConfig = topology.noIpv6;
      };
    }) topology.spareInterfaces
  );

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
  };
}

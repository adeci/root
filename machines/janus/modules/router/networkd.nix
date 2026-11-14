{ lib, self, ... }:
let
  inherit (self.inventory.lan) vlans;
  inherit (self.inventory.router) interfaces ports;

  # Each VLAN's 802.1Q device on the LAN trunk.
  vlanDevice = vlan: "vlan${toString vlan.id}";

  # No IPv6 on the LAN for now; Tailscale manages its own.
  noIpv6 = {
    LinkLocalAddressing = "no";
    IPv6AcceptRA = false;
  };

  spareInterfaces = lib.subtractLists (lib.attrValues interfaces) (lib.attrValues ports);
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
      lib.nameValuePair "20-${vlanDevice vlan}" {
        netdevConfig = {
          Name = vlanDevice vlan;
          Kind = "vlan";
        };
        vlanConfig.Id = vlan.id;
      }
    ) vlans
    // {
      "10-${vlans.mgmt.interface}".netdevConfig = {
        Name = vlans.mgmt.interface;
        Kind = "bridge";
      };
    };

  systemd.network.networks = {
    "10-wan" = {
      matchConfig.Name = interfaces.wan;
      networkConfig = noIpv6 // {
        DHCP = "ipv4";
      };
      dhcpV4Config.UseDNS = false;
    };

    "20-lan" = {
      matchConfig.Name = interfaces.lan;
      linkConfig.RequiredForOnline = "carrier";
      networkConfig = noIpv6 // {
        VLAN = map vlanDevice (lib.attrValues vlans);
      };
    };

    # The mgmt VLAN arrives untagged on the mgmt port and tagged on the LAN trunk; one bridge joins both.
    "20-mgmt" = {
      matchConfig.Name = interfaces.mgmt;
      linkConfig.RequiredForOnline = "no";
      networkConfig = noIpv6 // {
        Bridge = vlans.mgmt.interface;
      };
    };

    "20-${vlanDevice vlans.mgmt}-bridge" = {
      matchConfig.Name = vlanDevice vlans.mgmt;
      linkConfig.RequiredForOnline = "no";
      networkConfig = noIpv6 // {
        Bridge = vlans.mgmt.interface;
      };
    };
  }
  // lib.mapAttrs' (
    _: vlan:
    lib.nameValuePair "30-${vlan.interface}" {
      matchConfig.Name = vlan.interface;
      address = [ "${vlan.gateway}/${lib.last (lib.splitString "/" vlan.cidr)}" ];
      linkConfig.RequiredForOnline = "no";
      networkConfig = noIpv6;
    }
  ) vlans
  // lib.listToAttrs (
    map (interface: {
      name = "90-spare-${interface}";
      value = {
        matchConfig.Name = interface;
        linkConfig.RequiredForOnline = "no";
        networkConfig = noIpv6;
      };
    }) spareInterfaces
  );

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
  };
}

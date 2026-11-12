{ lib, self }:
let
  inherit (self.resources) homelan;
  inherit (homelan) vlans;
  inherit (homelan.router) ports roles;

  wan = ports.${roles.wan};
  lan = ports.${roles.lan};
  mgmt = ports.${roles.mgmt};

  vlanInterface = vlan: "vlan${toString vlan.id}";
  subnetInterface = vlan: vlan.interface or (vlanInterface vlan);

  routedVlans = lib.filterAttrs (name: _: name != "mgmt") vlans;
  routedVlanInterfaces = lib.mapAttrsToList (_: vlanInterface) routedVlans;
  serviceInterfaces = routedVlanInterfaces ++ [ "br-mgmt" ];

  noIpv6 = {
    LinkLocalAddressing = "no";
    IPv6AcceptRA = false;
  };

  interfaceSet = interfaces: lib.concatMapStringsSep ", " (interface: ''"${interface}"'') interfaces;

  tailnetVlans = lib.filterAttrs (_: vlan: vlan.tailnet or false) vlans;
  tailnetInterfaces = lib.mapAttrsToList (_: subnetInterface) tailnetVlans;

  tailscaleRouteFlag = "--advertise-routes=${
    lib.concatMapStringsSep "," (vlan: vlan.cidr) (lib.attrValues tailnetVlans)
  }";
in
{
  inherit
    ports
    wan
    lan
    mgmt
    homelan
    vlans
    vlanInterface
    subnetInterface
    routedVlans
    routedVlanInterfaces
    serviceInterfaces
    noIpv6
    interfaceSet
    tailnetInterfaces
    tailscaleRouteFlag
    ;

  trunkVlanInterfaces = lib.mapAttrsToList (_: vlanInterface) vlans;
  physicalInterfaces = lib.attrValues ports;
  spareInterfaces = lib.subtractLists [
    wan
    lan
    mgmt
  ] (lib.attrValues ports);
}

# How the router's metrics name its interfaces, VLANs and the RouterOS ports on known cables.
{ homelan, routeros }:
let
  inherit (homelan.router) ports roles;

  vlans = builtins.sort (a: b: a.id < b.id) (
    map (name: {
      inherit name;
      inherit (homelan.vlans.${name}) id cidr;
      interface = homelan.vlans.${name}.interface or "vlan${toString homelan.vlans.${name}.id}";
    }) (builtins.attrNames homelan.vlans)
  );

  # A cable end "<device>:<port>" on a RouterOS device, or null for any other end.
  routerosEnd =
    end:
    let
      parts = builtins.match "([^:]+):(.+)" end;
      device = builtins.elemAt parts 0;
    in
    if parts != null && routeros.devices ? ${device} then
      {
        inherit device;
        port = builtins.elemAt parts 1;
      }
    else
      null;

  portsByDevice =
    ends:
    builtins.mapAttrs (_: map (end: end.port)) (
      builtins.groupBy (end: end.device) (builtins.filter (end: end != null) ends)
    );

  # The first RouterOS end of each cable, so a cable is reported once.
  firstRouterosEnd =
    link:
    let
      a = routerosEnd link.a;
    in
    if a != null then a else routerosEnd link.b;
in
{
  instance = homelan.router.machine;
  wan = ports.${roles.wan};
  lan = ports.${roles.lan};
  mgmt = ports.${roles.mgmt};
  inherit vlans;
  # RouterOS ports by device, at either end of a known cable.
  cabledPorts = portsByDevice (
    builtins.concatMap (link: [
      (routerosEnd link.a)
      (routerosEnd link.b)
    ]) homelan.links
  );
  # One RouterOS port by device for each known cable.
  cablePorts = portsByDevice (map firstRouterosEnd homelan.links);

  # Builds one query per device from its `name` and `interface` matchers, joined with `or`.
  onPorts =
    portsOf: query:
    let
      matchers =
        device: ''name="${device}", interface=~"${builtins.concatStringsSep "|" portsOf.${device}}"'';
    in
    builtins.concatStringsSep "\n  or " (
      map (device: query (matchers device)) (builtins.attrNames portsOf)
    );
}

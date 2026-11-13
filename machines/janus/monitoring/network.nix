# How the router's metrics name its interfaces, VLANs and the appliance ports on known cables.
inventory:
let
  inherit (inventory.router) ports roles;

  vlans = builtins.sort (a: b: a.id < b.id) (
    builtins.attrValues (
      builtins.mapAttrs (name: vlan: {
        inherit name;
        inherit (vlan) id cidr interface;
      }) inventory.lan.vlans
    )
  );

  # A portable machine comes and goes, so the port it docks into isn't expected to stay up.
  steadyCables = builtins.filter (
    cable: !(builtins.elem "portable" (inventory.machines.${cable.to}.tags or [ ]))
  ) inventory.lan.cables;

  # The port each cable is written on, so a cable is reported once.
  nearEnds = map (cable: {
    device = cable.appliance;
    inherit (cable) port;
  }) steadyCables;

  # The far ends that are appliance ports too.
  farEnds = map (cable: {
    device = cable.to;
    port = cable.toPort;
  }) (builtins.filter (cable: inventory.appliances ? ${cable.to}) steadyCables);

  portsByDevice =
    ends: builtins.mapAttrs (_: map (end: end.port)) (builtins.groupBy (end: end.device) ends);
in
{
  instance = inventory.router.machine;
  wan = ports.${roles.wan};
  lan = ports.${roles.lan};
  mgmt = ports.${roles.mgmt};
  inherit vlans;
  # Appliance ports by appliance, at either end of a known cable.
  cabledPorts = portsByDevice (nearEnds ++ farEnds);
  # One appliance port by appliance for each known cable.
  cablePorts = portsByDevice nearEnds;

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

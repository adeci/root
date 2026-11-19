# The router's network as its metrics name it.
inventory:
let
  # A portable machine comes and goes, so the port it docks into isn't expected to stay up.
  steadyCables = builtins.filter (
    cable: !(builtins.elem "portable" (inventory.machines.${cable.to}.tags or [ ]))
  ) inventory.lan.cables;

  # The port each cable is written on.
  nearEnds = map (cable: {
    inherit (cable) appliance port;
  }) steadyCables;

  # The other ends that are appliance ports too.
  farEnds = map (cable: {
    appliance = cable.to;
    port = cable.toPort;
  }) (builtins.filter (cable: inventory.appliances ? ${cable.to}) steadyCables);

  portsByAppliance =
    ends: builtins.mapAttrs (_: map (end: end.port)) (builtins.groupBy (end: end.appliance) ends);
in
{
  instance = inventory.router.machine;
  inherit (inventory.router) interfaces;
  appliances = builtins.attrNames inventory.appliances;
  # By id, so every panel lists them in the same order.
  vlans = builtins.sort (a: b: a.id < b.id) (
    builtins.attrValues (builtins.mapAttrs (name: vlan: vlan // { inherit name; }) inventory.lan.vlans)
  );
  # Appliance ports at either end of a known cable.
  cabledPorts = portsByAppliance (nearEnds ++ farEnds);
  # One appliance port for each known cable.
  cableNearEnds = portsByAppliance nearEnds;
  # What each known cable reaches, by the appliance port it is written on, as "nexus ether2".
  cableEnds = builtins.listToAttrs (
    map (cable: {
      name = "${cable.appliance} ${cable.port}";
      value = cable.to;
    }) steadyCables
  );
  # The host each reserved address belongs to.
  hostsByAddress = builtins.listToAttrs (
    map (host: {
      name = inventory.lan.hosts.${host}.ip;
      value = host;
    }) (builtins.attrNames inventory.lan.hosts)
  );

  # One query per appliance, matching its ports by `name` and `interface`, joined with `or`.
  onPorts =
    portsOf: query:
    let
      matchers =
        appliance:
        ''name="${appliance}", interface=~"${builtins.concatStringsSep "|" portsOf.${appliance}}"'';
    in
    builtins.concatStringsSep "\n  or " (
      map (appliance: query (matchers appliance)) (builtins.attrNames portsOf)
    );
}

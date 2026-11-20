# The router's network as its metrics name it.
inventory:
let
  router = ''instance="${inventory.router.machine}"'';

  # Portable machines come and go; their dock ports aren't expected up.
  steadyCables = builtins.filter (
    cable: !(builtins.elem "portable" (inventory.machines.${cable.to}.tags or [ ]))
  ) inventory.lan.cables;

  # Appliance end of each cable.
  nearEnds = map (cable: {
    inherit (cable) appliance port;
  }) steadyCables;

  portsByAppliance =
    ends: builtins.mapAttrs (_: map (end: end.port)) (builtins.groupBy (end: end.appliance) ends);

  # By id, so every panel lists them in the same order.
  vlans = builtins.sort (a: b: a.id < b.id) (
    builtins.attrValues (builtins.mapAttrs (name: vlan: vlan // { inherit name; }) inventory.lan.vlans)
  );

  hostsByAddress = builtins.listToAttrs (
    map (host: {
      name = inventory.lan.hosts.${host}.ip;
      value = host;
    }) (builtins.attrNames inventory.lan.hosts)
  );

  # An address, or its first octets, in a regex.
  dotsOnly = builtins.replaceStrings [ "." ] [ "[.]" ];

  # Every reserved address, as a regex.
  reservedAddresses = builtins.concatStringsSep "|" (
    map dotsOnly (builtins.attrNames hostsByAddress)
  );

  # How long a device must have taken no lease to count as new.
  newDeviceDays = 30;

  # The deploy guard's lease check is janus itself, not a device.
  guardCheck = import ../modules/deploy-guard/check-client.nix;
in
{
  instance = inventory.router.machine;
  inherit (inventory.router) interfaces;
  appliances = builtins.attrNames inventory.appliances;
  inherit
    vlans
    hostsByAddress
    reservedAddresses
    newDeviceDays
    ;
  # One appliance port for each known cable.
  cableNearEnds = portsByAppliance nearEnds;
  # Machine at the other end of each cable, keyed like "nexus ether2".
  cableEnds = builtins.listToAttrs (
    map (cable: {
      name = "${cable.appliance} ${cable.port}";
      value = cable.to;
    }) steadyCables
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

  # New MACs on own networks; silent until there are 30 days of lease records.
  newDevices =
    within:
    let
      leases = "janus_dhcp_lease_renewed_timestamp_seconds{${router}}";
      onNetwork =
        vlan:
        ''label_replace(min_over_time(janus_dhcp_lease_renewed_timestamp_seconds{${router}, address=~"${dotsOnly vlan.prefix}[.].+", address!~"${reservedAddresses}", mac!="${guardCheck.mac}"}[${within}]), "network", "${vlan.name}", "", "")'';
      ownVlans = builtins.filter (vlan: vlan.ownDevices) vlans;
    in
    "bottomk by (mac) (1, (${builtins.concatStringsSep " or " (map onNetwork ownVlans)}) unless on (mac) present_over_time(${leases}[${toString newDeviceDays}d] offset ${within})) and on () present_over_time(${leases}[${within}] offset ${toString newDeviceDays}d)";
}

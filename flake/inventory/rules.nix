# Rules for network.nix that types can't express.
{ config, lib, ... }:
let
  inherit (config.lan) cables hosts vlans;
  inherit (config) appliances router;
  inherit (config.routeros) models;
  inherit (import ./lib.nix { inherit lib; }) addressNumber carriedVlans inBlock;

  # A value and the path in network.nix it is written at.
  valueAt = path: value: { inherit path value; };

  # One rule per value among `values` (each from valueAt): only one path holds it. `what` names the value in messages.
  usedOnce =
    what: values:
    lib.mapAttrsToList (
      value: holders:
      let
        paths = lib.concatMapStringsSep ", " (holder: holder.path) holders;
      in
      {
        assertion = lib.length holders == 1;
        message = "${paths}: ${what} ${value} is used more than once";
      }
    ) (lib.groupBy (holder: holder.value) values);

  inVlan = vlan: inBlock vlan.cidr;

  # Every LAN reservation's host name, at the path that makes it.
  reservations =
    lib.mapAttrsToList (name: _: valueAt "devices.${name}.lan" name) config.devices
    ++ lib.mapAttrsToList (name: _: valueAt "vms.${name}.lan" name) config.vms
    ++ lib.mapAttrsToList (name: _: valueAt "appliances.${name}.lan" name) appliances
    ++ lib.concatLists (
      lib.mapAttrsToList (
        name: machine:
        lib.optionals (machine.lan != null) (
          [ (valueAt "machines.${name}.lan" name) ]
          ++ lib.mapAttrsToList (
            label: _: valueAt "machines.${name}.lan.extra.${label}" "${name}-${label}"
          ) machine.lan.extra
        )
      ) config.machines
    );

  # The path that reserves each host name.
  reservedAt = lib.listToAttrs (
    map (reservation: lib.nameValuePair reservation.value reservation.path) reservations
  );

  # Where a cable is written, and where it leads as written there.
  cablePath = cable: "appliances.${cable.appliance}.ports.${cable.port}.cable";
  leadsTo = cable: if cable.toPort == null then cable.to else "${cable.to}:${cable.toPort}";

  # Whether a cable leads to a host rather than to an appliance or the router.
  leadsToHost = cable: !(appliances ? ${cable.to}) && cable.to != router.machine;

  # Whether a cable to an appliance or the router names a port it has.
  leadsToExistingPort =
    cable:
    if appliances ? ${cable.to} then
      lib.elem cable.toPort models.${appliances.${cable.to}.model}.ports
    else if cable.to == router.machine then
      cable.toPort != null && router.ports ? ${cable.toPort}
    else
      true;

  # What a port carries, in words.
  describeCarried =
    carried:
    if carried.untagged == null && carried.tagged == [ ] then
      "nothing"
    else
      lib.concatStringsSep " and " (
        lib.optional (carried.untagged != null) "${carried.untagged} untagged"
        ++ lib.optional (carried.tagged != [ ]) "${lib.concatStringsSep "+" carried.tagged} tagged"
      );

  # What a router port carries, by the label on its case.
  routerPortCarries =
    label:
    if label == router.roles.lan then
      carriedVlans null (lib.attrNames vlans)
    else if label == router.roles.mgmt then
      carriedVlans "mgmt" [ ]
    else
      carriedVlans null [ ];

  # What the port a cable leads to carries; null where the inventory can't tell: a named NIC, or a machine off the LAN.
  carriedWhereItLeads =
    cable:
    if appliances ? ${cable.to} then
      appliances.${cable.to}.ports.${cable.toPort}.carries
    else if cable.to == router.machine then
      routerPortCarries cable.toPort
    else if cable.toPort == null && hosts ? ${cable.to} then
      carriedVlans hosts.${cable.to}.vlan [ ]
    else
      null;

  accessPoints = lib.filterAttrs (_: appliance: appliance.wifi != [ ]) appliances;

  # The rules

  uniqueVlanIds = usedOnce "id" (
    lib.mapAttrsToList (name: vlan: valueAt "lan.vlans.${name}.id" (toString vlan.id)) vlans
  );

  gatewaysInVlans = lib.mapAttrsToList (name: vlan: {
    assertion = inVlan vlan vlan.gateway;
    message = "lan.vlans.${name}.gateway: ${vlan.gateway} is outside ${vlan.cidr}";
  }) vlans;

  poolsInVlans = lib.mapAttrsToList (name: vlan: {
    assertion = inVlan vlan vlan.dhcpPool.start && inVlan vlan vlan.dhcpPool.end;
    message = "lan.vlans.${name}.dhcpPool: ${vlan.dhcpPool.start}-${vlan.dhcpPool.end} is outside ${vlan.cidr}";
  }) vlans;

  # Cables and DNS records name hosts alone.
  uniqueHostNames = usedOnce "name" (
    reservations
    ++ lib.mapAttrsToList (name: _: valueAt "machines.${name}" name) (
      lib.filterAttrs (_: machine: machine.lan == null) config.machines
    )
  );

  hostsInTheirVlans = lib.mapAttrsToList (name: host: {
    assertion = inVlan vlans.${host.vlan} host.ip;
    message = "${reservedAt.${name}}: ${host.ip} is outside ${host.vlan}'s ${vlans.${host.vlan}.cidr}";
  }) hosts;

  hostsOutsidePools = lib.mapAttrsToList (
    name: host:
    let
      pool = vlans.${host.vlan}.dhcpPool;
      address = addressNumber host.ip;
    in
    {
      assertion = address < addressNumber pool.start || address > addressNumber pool.end;
      message = "${reservedAt.${name}}: ${host.ip} is inside ${host.vlan}'s DHCP pool ${pool.start}-${pool.end}";
    }
  ) hosts;

  uniqueIps = usedOnce "ip" (
    lib.mapAttrsToList (name: host: valueAt reservedAt.${name} host.ip) hosts
  );

  uniqueMacs = usedOnce "MAC" (
    lib.mapAttrsToList (name: host: valueAt reservedAt.${name} (lib.toLower host.mac)) hosts
  );

  uniqueClientIds = usedOnce "DHCP client id" (
    lib.mapAttrsToList (name: host: valueAt reservedAt.${name} (lib.toLower host.clientId)) (
      lib.filterAttrs (_: host: host.clientId != null) hosts
    )
  );

  uniqueTailnetAddresses = usedOnce "tailnet address" (
    lib.mapAttrsToList (name: machine: valueAt "machines.${name}.tailnet" machine.tailnet) (
      lib.filterAttrs (_: machine: machine.tailnet != null) config.machines
    )
  );

  tailnetRecordsResolve = lib.mapAttrsToList (fqdn: record: {
    assertion = config.machines.${record.tailnet}.tailnet != null;
    message = ''lan.dns."${fqdn}".tailnet: ${record.tailnet} has no tailnet address'';
  }) (lib.filterAttrs (_: record: record ? tailnet) config.lan.dns);

  appliancePortsExist = lib.concatLists (
    lib.mapAttrsToList (
      name: appliance:
      let
        # Every port the appliance's entry mentions, at the path that mentions it.
        portsMentioned =
          lib.mapAttrsToList (port: _: valueAt "appliances.${name}.ports.${port}" port) appliance.ports
          ++ [ (valueAt "appliances.${name}.managementPort" appliance.managementPort) ]
          ++ lib.optional (appliance.fallbackPort != appliance.managementPort) (
            valueAt "appliances.${name}.fallbackPort" appliance.fallbackPort
          );
      in
      map (port: {
        assertion = lib.elem port.value models.${appliance.model}.ports;
        message = "${port.path}: a ${appliance.model} has no port ${port.value}";
      }) portsMentioned
    ) appliances
  );

  # A trunk tags every VLAN of its switch, so a `tagged` list on it would go unused.
  trunksListNoTaggedVlans = lib.concatLists (
    lib.mapAttrsToList (
      name: appliance:
      lib.mapAttrsToList (port: settings: {
        assertion = !settings.trunk || settings.tagged == [ ];
        message = "appliances.${name}.ports.${port}: a trunk carries every VLAN tagged; drop its `tagged` list";
      }) appliance.ports
    ) appliances
  );

  accessPointsHaveOnePrimaryWifi = lib.mapAttrsToList (
    name: accessPoint:
    let
      primaries = lib.filter (network: config.wifi.${network}.primary) accessPoint.wifi;
    in
    {
      assertion = lib.length primaries == 1;
      message = "appliances.${name}.wifi: an access point broadcasts exactly one primary network, not ${toString (lib.length primaries)}";
    }
  ) accessPoints;

  cablesLeadToExistingPorts = map (cable: {
    assertion = leadsToExistingPort cable;
    message =
      if cable.toPort == null then
        "${cablePath cable}: ${cable.to} needs a port"
      else if appliances ? ${cable.to} then
        "${cablePath cable}: ${cable.to}, a ${appliances.${cable.to}.model}, has no port ${cable.toPort}"
      else
        "${cablePath cable}: ${cable.to} has no port ${cable.toPort} in router.ports";
  }) cables;

  # The router's wan port holds the ISP's cable.
  onePlugPerPort = usedOnce "port" (
    [ (valueAt "router.roles.wan" "${router.machine}:${router.roles.wan}") ]
    ++ lib.concatMap (
      cable:
      [ (valueAt "appliances.${cable.appliance}.ports.${cable.port}" "${cable.appliance}:${cable.port}") ]
      ++ lib.optional (cable.toPort != null) (valueAt (cablePath cable) (leadsTo cable))
    ) cables
  );

  # A cable that names a host but not its NIC must be the host's only cable.
  hostsCabledWithoutNicHaveOneCable =
    let
      hostCables = lib.filter leadsToHost cables;
      hostsCabledWithoutNic = lib.unique (
        map (cable: cable.to) (lib.filter (cable: cable.toPort == null) hostCables)
      );
    in
    map (
      host:
      let
        itsCables = lib.filter (cable: cable.to == host) hostCables;
        paths = lib.concatMapStringsSep ", " cablePath itsCables;
      in
      {
        assertion = lib.length itsCables == 1;
        message = "${paths}: ${host} has more than one cable, so each must name its NIC";
      }
    ) hostsCabledWithoutNic;

  # The wan port's cable, to the ISP, is implied.
  routerRolesCabled = lib.mapAttrsToList (role: label: {
    assertion = lib.any (cable: cable.to == router.machine && cable.toPort == label) cables;
    message = "router.roles.${role}: ${router.machine}:${label} has no cable";
  }) (removeAttrs router.roles [ "wan" ]);

  cablesAgreeOnVlans = map (
    cable:
    let
      here = appliances.${cable.appliance}.ports.${cable.port}.carries;
      there = carriedWhereItLeads cable;
    in
    {
      assertion = there == null || here == there;
      message = "appliances.${cable.appliance}.ports.${cable.port}: carries ${describeCarried here}, but ${leadsTo cable} carries ${describeCarried there}";
    }
  ) (lib.filter leadsToExistingPort cables);
in
{
  assertions = lib.concatLists [
    uniqueVlanIds
    gatewaysInVlans
    poolsInVlans
    uniqueHostNames
    hostsInTheirVlans
    hostsOutsidePools
    uniqueIps
    uniqueMacs
    uniqueClientIds
    uniqueTailnetAddresses
    tailnetRecordsResolve
    appliancePortsExist
    trunksListNoTaggedVlans
    accessPointsHaveOnePrimaryWifi
    cablesLeadToExistingPorts
    onePlugPerPort
    hostsCabledWithoutNicHaveOneCable
    routerRolesCabled
    cablesAgreeOnVlans
  ];
}

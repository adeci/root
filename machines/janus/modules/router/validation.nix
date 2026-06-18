{
  lib,
  self,
  ...
}:
let
  topology = import ./topology.nix { inherit lib self; };

  inherit (topology) homelan vlans;
  devices = homelan.hosts;
  dnsDevices = lib.filterAttrs (_: host: host.publishDns or true) devices;

  countMatching = pred: values: builtins.length (builtins.filter pred values);
  duplicates =
    values:
    lib.filter (value: countMatching (candidate: candidate == value) values > 1) (lib.unique values);
  lower = value: lib.toLower value;

  knownVlanHosts = lib.filterAttrs (_: host: host ? vlan && lib.hasAttr host.vlan vlans) devices;

  allAliases = lib.concatMap (host: host.aliases or [ ]) (lib.attrValues dnsDevices);
  hostIps = lib.mapAttrsToList (_: host: host.ip or null) devices;
  hostMacs = lib.mapAttrsToList (_: host: lower host.mac) (
    lib.filterAttrs (_: host: host ? mac) devices
  );
  hostClientIds = lib.mapAttrsToList (_: host: lower host.clientId) (
    lib.filterAttrs (_: host: host ? clientId) devices
  );

  hostsMissingIp = lib.attrNames (lib.filterAttrs (_: host: !(host ? ip)) devices);
  hostsMissingReservationId = lib.attrNames (
    lib.filterAttrs (_: host: !(host ? mac || host ? clientId)) devices
  );
  hostsWithUnknownVlans = lib.attrNames (
    lib.filterAttrs (_: host: !(host ? vlan) || !(lib.hasAttr host.vlan vlans)) devices
  );
  hostsOutsideVlan = lib.attrNames (
    lib.filterAttrs (
      _: host: !(host ? ip) || !(lib.hasPrefix "${vlans.${host.vlan}.prefix}." host.ip)
    ) knownVlanHosts
  );

  ipLastOctet =
    ip:
    let
      match = builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.([0-9]+)" ip;
    in
    if match == null then null else lib.toInt (builtins.head match);

  ipInDhcpPool =
    vlan: ip:
    let
      octet = ipLastOctet ip;
      start = ipLastOctet vlan.dhcpPool.start;
      end = ipLastOctet vlan.dhcpPool.end;
    in
    octet != null && start != null && end != null && octet >= start && octet <= end;

  hostsInsideDhcpPools = lib.attrNames (
    lib.filterAttrs (
      _: host:
      host ? ip && host ? vlan && lib.hasAttr host.vlan vlans && ipInDhcpPool vlans.${host.vlan} host.ip
    ) devices
  );

  vlanIds = map (vlan: vlan.id) (lib.attrValues vlans);
  vlansWithBadGateway = lib.attrNames (
    lib.filterAttrs (_: vlan: !(lib.hasPrefix "${vlan.prefix}." vlan.gateway)) vlans
  );
  vlansWithBadDhcpPool = lib.attrNames (
    lib.filterAttrs (
      _: vlan:
      !(lib.hasPrefix "${vlan.prefix}." vlan.dhcpPool.start)
      || !(lib.hasPrefix "${vlan.prefix}." vlan.dhcpPool.end)
    ) vlans
  );

  aliasHostConflicts = lib.intersectLists allAliases (lib.attrNames devices);
  duplicateAliases = duplicates allAliases;
  duplicateIps = duplicates (lib.filter (ip: ip != null) hostIps);
  duplicateMacs = duplicates hostMacs;
  duplicateClientIds = duplicates hostClientIds;
in
{
  assertions = [
    {
      assertion = lib.length vlanIds == lib.length (lib.unique vlanIds);
      message = "homelan VLAN IDs must be unique";
    }
    {
      assertion = vlansWithBadGateway == [ ];
      message = "homelan VLAN gateways must live inside their VLAN prefix: ${lib.concatStringsSep ", " vlansWithBadGateway}";
    }
    {
      assertion = vlansWithBadDhcpPool == [ ];
      message = "homelan DHCP pools must live inside their VLAN prefix: ${lib.concatStringsSep ", " vlansWithBadDhcpPool}";
    }
    {
      assertion = hostsMissingIp == [ ];
      message = "homelan hosts must declare ip: ${lib.concatStringsSep ", " hostsMissingIp}";
    }
    {
      assertion = hostsMissingReservationId == [ ];
      message = "homelan hosts must declare mac or clientId: ${lib.concatStringsSep ", " hostsMissingReservationId}";
    }
    {
      assertion = hostsWithUnknownVlans == [ ];
      message = "homelan hosts reference unknown VLANs: ${lib.concatStringsSep ", " hostsWithUnknownVlans}";
    }
    {
      assertion = hostsOutsideVlan == [ ];
      message = "homelan host IPs must match their VLAN prefix: ${lib.concatStringsSep ", " hostsOutsideVlan}";
    }
    {
      assertion = hostsInsideDhcpPools == [ ];
      message = "homelan static host reservations must stay outside DHCP pools: ${lib.concatStringsSep ", " hostsInsideDhcpPools}";
    }
    {
      assertion = duplicateIps == [ ];
      message = "homelan host IPs must be unique: ${lib.concatStringsSep ", " duplicateIps}";
    }
    {
      assertion = duplicateMacs == [ ];
      message = "homelan host MACs must be unique: ${lib.concatStringsSep ", " duplicateMacs}";
    }
    {
      assertion = duplicateClientIds == [ ];
      message = "homelan DHCP client IDs must be unique: ${lib.concatStringsSep ", " duplicateClientIds}";
    }
    {
      assertion = duplicateAliases == [ ];
      message = "homelan aliases must be unique: ${lib.concatStringsSep ", " duplicateAliases}";
    }
    {
      assertion = aliasHostConflicts == [ ];
      message = "homelan aliases conflict with host names: ${lib.concatStringsSep ", " aliasHostConflicts}";
    }
  ];
}

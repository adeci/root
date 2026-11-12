# Inventory mistakes, each as "<file> (<where>): <what is wrong>"; empty when the inventory is consistent.
{
  lib,
  machines,
  resources,
  instances,
}:
let
  inherit (resources)
    b2
    cloudflare
    homelan
    ingress
    routeros
    tailscale
    ;
  inherit (homelan)
    hosts
    vlans
    router
    links
    ;

  machinesFile = "inventory/machines.nix";
  homelanFile = "inventory/resources/homelan.nix";
  ingressFile = "inventory/resources/ingress.nix";
  cloudflareFile = "inventory/resources/cloudflare.nix";
  b2File = "inventory/resources/b2.nix";
  routerosFile = "inventory/resources/routeros/default.nix";
  routerosModelsFile = "inventory/resources/routeros/models.nix";
  routerosDeviceFile = name: "inventory/resources/routeros/${name}.nix";
  instancesFile = "inventory/instances.nix";

  machineClasses = [
    "nixos"
    "darwin"
  ];

  concatMapAttrsToList = f: attrs: lib.concatLists (lib.mapAttrsToList f attrs);

  place = file: location: { inherit file location; };

  # Places as "<file> (<location>, ...)", grouped by file.
  describe =
    places:
    lib.concatStringsSep ", " (
      lib.mapAttrsToList (
        file: group: "${file} (${lib.concatStringsSep ", " (lib.unique (map (p: p.location) group))})"
      ) (lib.groupBy (p: p.file) places)
    );

  problem = places: message: "${describe places}: ${message}";
  problemAt = file: location: problem [ (place file location) ];

  # One problem per value that more than one { place, value } entry holds.
  duplicated =
    what: entries:
    lib.concatMap (
      value:
      let
        holders = lib.filter (entry: entry.value == value) entries;
      in
      lib.optional (lib.length holders > 1) (
        problem (map (entry: entry.place) holders) "${what} ${toString value} is used more than once"
      )
    ) (lib.unique (map (entry: entry.value) entries));

  unknownMachine =
    file: location: name:
    lib.optional (!(machines ? ${name})) (
      problemAt file location "${name} is not a machine in ${machinesFile}"
    );

  unknownEdge =
    location: name:
    lib.optional (!(ingress.edges ? ${name})) (
      problemAt cloudflareFile location "${name} is not an edge in ${ingressFile}"
    );

  # An IPv4 address as a number, null when malformed.
  ipv4 =
    address:
    let
      octets = builtins.match "([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})" address;
      values = map lib.toIntBase10 octets;
    in
    if octets == null || lib.any (value: value > 255) values then
      null
    else
      lib.foldl' (number: value: number * 256 + value) 0 values;

  inCidr =
    cidr: address:
    let
      block = builtins.match "(.+)/([0-9]+)" cidr;
      size = lib.foldl' (product: _: product * 2) 1 (lib.range 1 (32 - lib.toInt (lib.last block)));
      ip = ipv4 address;
    in
    ip != null && builtins.div ip size == builtins.div (ipv4 (lib.head block)) size;

  inPrefix = vlan: lib.hasPrefix "${vlan.prefix}.";

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

  # Where each LAN host's reservation is written; a machine's extra interfaces become hosts named <machine>-<label>.
  hostPlaces =
    lib.mapAttrs (name: _: place homelanFile "devices.${name}") hosts
    // lib.concatMapAttrs (
      name: machine:
      lib.optionalAttrs (machine ? lan) (
        {
          ${name} = place machinesFile "${name}.lan";
        }
        // lib.mapAttrs' (
          label: _: lib.nameValuePair "${name}-${label}" (place machinesFile "${name}.lan.extra.${label}")
        ) (machine.lan.extra or { })
      )
    ) machines
    // lib.mapAttrs (name: _: place (routerosDeviceFile name) "lan") routeros.devices;

  # Each host's value from valueOf, skipping hosts where it is null.
  hostEntries =
    valueOf:
    concatMapAttrsToList (
      name: host:
      let
        value = valueOf host;
      in
      lib.optional (value != null) {
        place = hostPlaces.${name};
        inherit value;
      }
    ) hosts;

  vlanProblems =
    concatMapAttrsToList (
      name: vlan:
      lib.optional (!(inPrefix vlan vlan.gateway)) (
        problemAt homelanFile "vlans.${name}.gateway"
          "${vlan.gateway} is outside the VLAN's prefix ${vlan.prefix}"
      )
      ++ lib.optional (!(inPrefix vlan vlan.dhcpPool.start && inPrefix vlan vlan.dhcpPool.end)) (
        problemAt homelanFile "vlans.${name}.dhcpPool"
          "${vlan.dhcpPool.start}-${vlan.dhcpPool.end} is outside the VLAN's prefix ${vlan.prefix}"
      )
    ) vlans
    ++ duplicated "VLAN id" (
      lib.mapAttrsToList (name: vlan: {
        place = place homelanFile "vlans.${name}.id";
        value = vlan.id;
      }) vlans
    );

  hostProblems =
    concatMapAttrsToList (
      name: host:
      let
        report = problem [ hostPlaces.${name} ];
        vlan = vlans.${host.vlan};
      in
      lib.optional (!(host ? ip)) (report "ip is missing")
      ++ lib.optional (!(host ? mac || host ? clientId)) (report "mac and clientId are both missing")
      ++ (
        if !(host ? vlan) then
          [ (report "vlan is missing") ]
        else if !(vlans ? ${host.vlan}) then
          [ (report "vlan ${host.vlan} is not a VLAN in ${homelanFile}") ]
        else
          lib.optionals (host ? ip) (
            lib.optional (!(inPrefix vlan host.ip)) (
              report "ip ${host.ip} is outside VLAN ${host.vlan}'s prefix ${vlan.prefix}"
            )
            ++ lib.optional (ipInDhcpPool vlan host.ip) (
              report "ip ${host.ip} is inside VLAN ${host.vlan}'s DHCP pool ${vlan.dhcpPool.start}-${vlan.dhcpPool.end}"
            )
          )
      )
    ) hosts
    ++ duplicated "ip" (hostEntries (host: host.ip or null))
    ++ duplicated "MAC" (hostEntries (host: if host ? mac then lib.toLower host.mac else null))
    ++ duplicated "DHCP client ID" (
      hostEntries (host: if host ? clientId then lib.toLower host.clientId else null)
    );

  machineProblems =
    concatMapAttrsToList (
      name: machine:
      lib.optional (!(lib.elem (machine.class or "nixos") machineClasses)) (
        problemAt machinesFile "${name}.class"
          "${builtins.toJSON machine.class} is neither \"nixos\" nor \"darwin\""
      )
      ++ lib.optional (machine ? tailnet && !(inCidr tailscale.cidr machine.tailnet)) (
        problemAt machinesFile "${name}.tailnet"
          "${machine.tailnet} is outside the tailnet's ${tailscale.cidr}"
      )
    ) machines
    ++ duplicated "tailnet address" (
      concatMapAttrsToList (
        name: machine:
        lib.optional (machine ? tailnet) {
          place = place machinesFile "${name}.tailnet";
          value = machine.tailnet;
        }
      ) machines
    );

  upstreamPattern = "([^.]+)\\.${lib.escapeRegex tailscale.domain}:([0-9]{1,5})";

  streamProblems = concatMapAttrsToList (
    edge: streams:
    lib.concatMap (
      stream:
      let
        location = "streams.${edge} \"${stream.name}\" upstream";
        upstream = builtins.match upstreamPattern stream.upstream;
        port = lib.toIntBase10 (lib.last upstream);
      in
      if upstream == null || port < 1 || port > 65535 then
        [
          (problemAt ingressFile location "${stream.upstream} is not <machine>.${tailscale.domain}:<port>")
        ]
      else
        unknownMachine ingressFile location (lib.head upstream)
    ) streams
    ++ duplicated "stream name" (
      map (stream: {
        place = place ingressFile "streams.${edge}";
        value = stream.name;
      }) streams
    )
  ) ingress.streams;

  # Static firewall rules and streams of an edge share its protocol/port space.
  portProblems = lib.concatMap (
    edge:
    duplicated "port" (
      map (rule: {
        place = place ingressFile "edges.${edge}.firewall.staticRules \"${rule.description or ""}\"";
        value = "${rule.protocol}/${toString rule.port}";
      }) (ingress.edges.${edge}.firewall.staticRules or [ ])
      ++ map (stream: {
        place = place ingressFile "streams.${edge} \"${stream.name}\"";
        value = "${stream.protocol}/${toString stream.listen}";
      }) (ingress.streams.${edge} or [ ])
    )
  ) (lib.unique (lib.attrNames ingress.edges ++ lib.attrNames ingress.streams));

  referenceProblems =
    concatMapAttrsToList (
      name: _: unknownMachine cloudflareFile "tunnels.${name}" name
    ) cloudflare.tunnels
    ++ concatMapAttrsToList (name: _: unknownMachine ingressFile "edges.${name}" name) ingress.edges
    ++ concatMapAttrsToList (name: _: unknownMachine ingressFile "streams.${name}" name) ingress.streams
    ++ concatMapAttrsToList (
      name: bucket:
      lib.optionals (bucket ? credentials.machine) (
        unknownMachine b2File "buckets.${name}.credentials.machine" bucket.credentials.machine
      )
    ) b2.buckets
    ++ unknownMachine routerosFile "exporter.machine" routeros.exporter.machine
    ++ concatMapAttrsToList (
      name: device:
      lib.optional (!(routeros.models ? ${device.model})) (
        problemAt (routerosDeviceFile name) "model"
          "${device.model} is not a model in ${routerosModelsFile}"
      )
    ) routeros.devices
    ++ unknownMachine homelanFile "router.machine" router.machine
    ++ concatMapAttrsToList (
      name: record:
      lib.optionals (record ? edge) (unknownEdge "dns.${name}.edge" record.edge)
      ++ lib.optionals (record ? ingressStream.edge) (
        unknownEdge "dns.${name}.ingressStream.edge" record.ingressStream.edge
      )
    ) cloudflare.dns
    ++ streamProblems
    ++ portProblems;

  # Clan ignores role members that aren't machines.
  instanceProblems = concatMapAttrsToList (
    name: instance:
    concatMapAttrsToList (
      role: members:
      concatMapAttrsToList (
        machine: _: unknownMachine instancesFile "${name}.roles.${role}.machines.${machine}" machine
      ) (members.machines or { })
    ) (instance.roles or { })
  ) instances;

  linkPlace = link: place homelanFile "links \"${link.a} <-> ${link.b}\"";

  # A cable end: "<device>:<port>" or a bare device, with the kind of device it names (null when unknown).
  cableEnd =
    link: text:
    let
      parts = builtins.match "([^:]*)(:(.*))?" text;
      device = lib.head parts;
    in
    {
      inherit link text device;
      port = lib.elemAt parts 2;
      kind =
        if device == router.machine then
          "router"
        else if device == "isp" then
          "isp"
        else if routeros.devices ? ${device} then
          "routeros"
        else if hosts ? ${device} then
          "host"
        else
          null;
    };

  cableEnds = link: [
    (cableEnd link link.a)
    (cableEnd link link.b)
  ];

  ends = lib.concatMap cableEnds links;

  # What a cable end carries, in words both ends must match.
  carrying =
    untagged: tagged:
    let
      tags = lib.concatStringsSep "+" (lib.sort lib.lessThan (lib.unique tagged));
    in
    if untagged == null && tags == "" then
      "nothing"
    else
      lib.concatStringsSep " and " (
        lib.optional (untagged != null) "${untagged} untagged" ++ lib.optional (tags != "") "${tags} tagged"
      );

  nothing = carrying null [ ];

  roleCarriage = {
    wan = "the WAN";
    lan = carrying null (lib.attrNames vlans);
    mgmt = carrying "mgmt" [ ];
  };

  routerCarriage = lib.mapAttrs' (
    role: port: lib.nameValuePair port (roleCarriage.${role} or nothing)
  ) router.roles;

  # The management port keeps the device's own VLAN untagged, tagging its WiFi VLANs or, as a trunk, the device's other VLANs; bridge ports carry only VLANs the device has.
  routerosCarriage =
    device: port:
    let
      settings = device.ports.${port} or { };
      deviceVlans = lib.attrNames (device.vlans or { });
      untagged = settings.vlan or device.defaultVlan;
    in
    if port == device.managementPort then
      carrying device.lan.vlan (
        if device ? wifi then
          lib.mapAttrsToList (_: ssid: ssid.vlan) device.wifi
        else
          lib.optionals (settings.trunk or false) (lib.remove device.lan.vlan deviceVlans)
      )
    else if !(device ? vlans) then
      nothing
    else if settings.trunk or false then
      carrying null deviceVlans
    else
      carrying (if lib.elem untagged deviceVlans then untagged else null) (
        lib.intersectLists deviceVlans (lib.optionals (settings.hybrid or false) (settings.tagged or [ ]))
      );

  # What an end carries: the router's ports by role, the ISP the WAN, a host its VLAN untagged unless the cable names another.
  carriage =
    end:
    {
      router = routerCarriage.${end.port} or nothing;
      isp = roleCarriage.wan;
      routeros = routerosCarriage routeros.devices.${end.device} end.port;
      host = carrying (end.link.vlan or hosts.${end.device}.vlan or null) [ ];
    }
    .${end.kind};

  endProblems =
    end:
    let
      report = problem [ (linkPlace end.link) ];
      inherit (routeros.devices.${end.device}) model;
    in
    if end.kind == null then
      [
        (report (
          if machines ? ${end.device} then
            "${end.device} has no lan in ${machinesFile}"
          else
            "${end.device} is not ${router.machine}, isp, a RouterOS device or a LAN host"
        ))
      ]
    else if end.port == null && (end.kind == "router" || end.kind == "routeros") then
      [ (report "${end.text} needs a port") ]
    else if end.kind == "router" && !(router.ports ? ${end.port}) then
      [ (report "${router.machine} has no port ${end.port} in router.ports") ]
    else if end.kind == "routeros" && !(routeros.models ? ${model}) then
      [ ] # already reported for the device
    else if end.kind == "routeros" && !(lib.elem end.port routeros.models.${model}.ports) then
      [ (report "${end.device}, a ${model}, has no port ${end.port}") ]
    else
      [ ];

  linkProblems =
    link:
    let
      linkEnds = cableEnds link;
      a = lib.head linkEnds;
      b = lib.last linkEnds;
      report = problem [ (linkPlace link) ];
      problems = lib.concatMap endProblems linkEnds;
    in
    if problems != [ ] then
      problems
    else
      lib.optional (carriage a != carriage b) (
        report "${a.text} carries ${carriage a}, but ${b.text} carries ${carriage b}"
      )
      ++ lib.optional (link ? vlan && !(lib.any (end: end.kind == "host") linkEnds)) (
        report "vlan only applies to a host's end"
      );

  # A host may leave out its port only while it has a single cable.
  portlessProblems =
    let
      portless = lib.filter (end: end.kind == "host" && end.port == null) ends;
    in
    lib.concatMap (
      host:
      let
        hostEnds = lib.filter (end: end.device == host) ends;
        places = map (end: linkPlace end.link) hostEnds;
      in
      lib.optional (lib.length hostEnds > 1) (
        problem places "${host} has more than one cable, so each end needs a port"
      )
    ) (lib.unique (map (end: end.device) portless));

  roleProblems = concatMapAttrsToList (
    role: port:
    let
      report = problemAt homelanFile "router.roles.${role}";
    in
    if !(router.ports ? ${port}) then
      [ (report "${router.machine} has no port ${port} in router.ports") ]
    else
      lib.optional (!(lib.any (end: end.kind == "router" && end.port == port) ends)) (
        report "${router.machine}:${port} has no cable in links"
      )
  ) router.roles;

  cablingProblems =
    lib.concatMap linkProblems links
    ++ duplicated "port" (
      map (end: {
        place = linkPlace end.link;
        value = end.text;
      }) (lib.filter (end: end.port != null) ends)
    )
    ++ portlessProblems
    ++ roleProblems;
in
vlanProblems
++ hostProblems
++ machineProblems
++ referenceProblems
++ instanceProblems
++ cablingProblems

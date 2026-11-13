# Rules for the data files besides network.nix.
{ config, lib, ... }:
let
  inherit (config)
    b2
    cloudflare
    ingress
    clanInstances
    ;

  isMachine = name: config.machines ? ${name};

  # A rule that the name written at `path` is a machine.
  mustBeMachine = path: name: {
    assertion = isMachine name;
    message = "${path}: ${name} is not a machine";
  };

  # A rule that the name written at `path` is an edge in ingress.nix.
  mustBeEdge = path: name: {
    assertion = ingress.edges ? ${name};
    message = "${path}: ${name} is not an edge in inventory/ingress.nix";
  };

  # The values that occur more than once in a list.
  usedMoreThanOnce =
    values: lib.unique (lib.filter (value: lib.count (other: other == value) values > 1) values);

  edges = lib.unique (lib.attrNames ingress.edges ++ lib.attrNames ingress.streams);

  # What an edge opens: its static firewall rules and its streams' listen ports.
  edgePorts =
    edge:
    map (rule: { inherit (rule) protocol port; }) (ingress.edges.${edge}.firewall.staticRules or [ ])
    ++ map (stream: {
      inherit (stream) protocol;
      port = stream.listen;
    }) (ingress.streams.${edge} or [ ]);

  # The rules

  tunnelMachines = map (name: mustBeMachine "inventory/cloudflare.nix tunnels.${name}" name) (
    lib.attrNames cloudflare.tunnels
  );

  edgeMachines =
    map (name: mustBeMachine "inventory/ingress.nix edges.${name}" name) (lib.attrNames ingress.edges)
    ++ map (name: mustBeMachine "inventory/ingress.nix streams.${name}" name) (
      lib.attrNames ingress.streams
    );

  bucketMachines = lib.mapAttrsToList (
    name: bucket:
    mustBeMachine "inventory/b2.nix buckets.${name}.credentials.machine" bucket.credentials.machine
  ) (lib.filterAttrs (_: bucket: bucket.credentials ? machine) b2.buckets);

  dnsEdges = lib.concatLists (
    lib.mapAttrsToList (
      name: record:
      lib.optional (record ? edge) (mustBeEdge "inventory/cloudflare.nix dns.${name}.edge" record.edge)
      ++ lib.optional (record ? ingressStream) (
        mustBeEdge "inventory/cloudflare.nix dns.${name}.ingressStream.edge" record.ingressStream.edge
      )
    ) cloudflare.dns
  );

  dnsStreams = lib.mapAttrsToList (
    name: record:
    let
      inherit (record.ingressStream) edge;
    in
    {
      assertion = lib.any (stream: stream.name == record.ingressStream.name) (
        ingress.streams.${edge} or [ ]
      );
      message = "inventory/cloudflare.nix dns.${name}.ingressStream: ${edge} has no stream ${record.ingressStream.name}";
    }
  ) (lib.filterAttrs (_: record: record ? ingressStream) cloudflare.dns);

  # A stream's upstream: <machine>.<tailnet domain>:<port>.
  upstreamPattern = "([^.]+)\\.${lib.escapeRegex config.tailnet.domain}:([0-9]{1,5})";

  streamUpstreams = lib.concatLists (
    lib.mapAttrsToList (
      edge:
      map (
        stream:
        let
          upstream = builtins.match upstreamPattern stream.upstream;
          port = lib.toIntBase10 (lib.last upstream);
        in
        {
          assertion = upstream != null && isMachine (lib.head upstream) && port >= 1 && port <= 65535;
          message = ''inventory/ingress.nix streams.${edge} "${stream.name}": upstream ${stream.upstream} is not <machine>.${config.tailnet.domain}:<port>'';
        }
      )
    ) ingress.streams
  );

  uniqueStreamNames = lib.mapAttrsToList (
    edge: streams:
    let
      reused = usedMoreThanOnce (map (stream: stream.name) streams);
    in
    {
      assertion = reused == [ ];
      message = "inventory/ingress.nix streams.${edge}: stream names ${toString reused} are used more than once";
    }
  ) ingress.streams;

  validEdgePorts = lib.concatMap (
    edge:
    map (open: {
      assertion =
        lib.elem open.protocol [
          "tcp"
          "udp"
        ]
        && builtins.isInt open.port
        && open.port >= 1
        && open.port <= 65535;
      message = "inventory/ingress.nix ${edge}: ${toString open.protocol}/${toString open.port} is not a tcp or udp port from 1 to 65535";
    }) (edgePorts edge)
  ) edges;

  # An edge's static firewall rules and its streams share one protocol/port space.
  uniqueEdgePorts = map (
    edge:
    let
      reused = usedMoreThanOnce (map (open: "${open.protocol}/${toString open.port}") (edgePorts edge));
    in
    {
      assertion = reused == [ ];
      message = "inventory/ingress.nix ${edge}: ports ${toString reused} are used more than once";
    }
  ) edges;

  # Clan ignores role members that aren't machines.
  instanceMachines = lib.concatLists (
    lib.mapAttrsToList (
      name: instance:
      lib.concatLists (
        lib.mapAttrsToList (
          role: members:
          map (machine: mustBeMachine "inventory/clan-instances.nix ${name}.roles.${role}.machines" machine) (
            lib.attrNames (members.machines or { })
          )
        ) (instance.roles or { })
      )
    ) clanInstances
  );
in
{
  assertions = lib.concatLists [
    tunnelMachines
    edgeMachines
    bucketMachines
    dnsEdges
    dnsStreams
    streamUpstreams
    uniqueStreamNames
    validEdgePorts
    uniqueEdgePorts
    instanceMachines
  ];
}

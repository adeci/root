# Rules for the data files besides network.nix.
{ config, lib, ... }:
let
  inherit (config)
    b2
    cloudflare
    ingress
    clanInstances
    tailscalePolicy
    ;

  isMachine = name: config.machines ? ${name};

  mustBeMachine = path: name: {
    assertion = isMachine name;
    message = "${path}: ${name} is not a machine";
  };

  mustBeEdge = path: name: {
    assertion = ingress.edges ? ${name};
    message = "${path}: ${name} is not an edge in inventory/ingress.nix";
  };

  usedMoreThanOnce =
    values: lib.unique (lib.filter (value: lib.count (other: other == value) values > 1) values);

  tunnelMachines = map (name: mustBeMachine "inventory/cloudflare.nix tunnels.${name}" name) (
    lib.attrNames cloudflare.tunnels
  );

  # Entries are keyed by service, so nothing else stops a host appearing twice.
  uniquePublicHosts =
    let
      reused = usedMoreThanOnce (
        lib.concatMap (routes: map (route: route.host) (lib.attrValues routes)) (
          lib.attrValues cloudflare.tunnels
        )
        ++ map (redirect: redirect.host) (lib.attrValues cloudflare.redirects)
      );
    in
    [
      {
        assertion = reused == [ ];
        message = "inventory/cloudflare.nix: more than one tunnel or redirect entry is for ${toString reused}";
      }
    ];

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

  dnsTailnet = lib.concatLists (
    lib.mapAttrsToList (
      name: record:
      [
        (mustBeMachine "inventory/cloudflare.nix dns.${name}.tailnet" record.tailnet)
      ]
      ++ lib.optional (isMachine record.tailnet) {
        assertion = config.tailnet.addresses ? ${record.tailnet};
        message = "inventory/cloudflare.nix dns.${name}.tailnet: ${record.tailnet} has no tailnet address";
      }
    ) (lib.filterAttrs (_: record: record ? tailnet) cloudflare.dns)
  );

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

  # An edge's static firewall rules and its streams share one protocol/port space.
  uniqueEdgePorts = map (
    edge:
    let
      reused = usedMoreThanOnce (
        map (rule: "${rule.protocol}/${toString rule.port}") (
          ingress.edges.${edge}.firewall.staticRules or [ ]
        )
        ++ map (stream: "${stream.protocol}/${toString stream.listen}") (ingress.streams.${edge} or [ ])
      );
    in
    {
      assertion = reused == [ ];
      message = "inventory/ingress.nix ${edge}: ports ${toString reused} are used more than once";
    }
  ) (lib.unique (lib.attrNames ingress.edges ++ lib.attrNames ingress.streams));

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

  # Policy tests can't use autogroup:shared as src (tailscale/tailscale#4416).
  sharedUserGrants = lib.filter (grant: lib.elem "autogroup:shared" grant.src) tailscalePolicy.grants;

  sharedUserDestinations =
    map (
      grant:
      let
        beyond = lib.subtractLists [
          "leviathan"
          "daedalus"
          "sequoia"
          "tag:gaming"
        ] grant.dst;
      in
      {
        assertion = beyond == [ ];
        message = "inventory/tailscale-policy.nix grants: shared users may reach only leviathan, daedalus, sequoia and tag:gaming, not ${toString beyond}";
      }
    ) sharedUserGrants
    ++ map (
      grant:
      let
        beyond = lib.subtractLists [ "tcp:8443" ] grant.ip;
      in
      {
        assertion = beyond == [ ];
        message = "inventory/tailscale-policy.nix grants: shared users on sequoia may reach only tcp:8443, not ${toString beyond}";
      }
    ) (lib.filter (grant: lib.elem "sequoia" grant.dst) sharedUserGrants);
in
{
  assertions = lib.concatLists [
    tunnelMachines
    uniquePublicHosts
    edgeMachines
    bucketMachines
    dnsEdges
    dnsStreams
    dnsTailnet
    streamUpstreams
    uniqueEdgePorts
    instanceMachines
    sharedUserDestinations
  ];
}

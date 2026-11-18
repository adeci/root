{
  clanInstances,
  lan,
  machines,
  tailnet,
  ...
}:
let
  # The owner's tailnet login.
  owner = "alex.decious@gmail.com";

  nixosMachines = builtins.filter (name: machines.${name}.class == "nixos") (
    builtins.attrNames tailnet.addresses
  );

  # The machines a clan instance gives a role: those it names, and those with a tag it names (all, nixos and darwin are clan's own).
  roleMachines =
    instance: role:
    let
      assigned = clanInstances.${instance}.roles.${role};
      tags = assigned.tags or [ ];
      hasTag =
        name: tag: tag == "all" || tag == machines.${name}.class || builtins.elem tag machines.${name}.tags;
    in
    builtins.filter (
      name:
      assigned.machines or { } ? ${name}
      || builtins.any (hasTag name) (if builtins.isList tags then tags else builtins.attrNames tags)
    ) (builtins.attrNames tailnet.addresses);

  monitoringServers = roleMachines "monitoring" "server";

  servers = builtins.filter (name: builtins.elem "tag:server" tailnet.deviceTags.${name}) (
    builtins.attrNames tailnet.deviceTags
  );

  # The ports of each agent's own exporters, from its settings in the monitoring instance: blackbox_exporter answers for its probes.
  exporterPorts = builtins.mapAttrs (
    _: agent:
    builtins.sort builtins.lessThan (
      builtins.attrValues agent.settings.exporters or { }
      ++ (if agent.settings.probes or { } != { } then [ 9115 ] else [ ])
    )
  ) clanInstances.monitoring.roles.agent.machines;
in
{
  hosts = tailnet.addresses;

  grants = [
    # The owner's devices administer every machine, and deploy to it as root@<machine>.<tailnet domain>.
    {
      src = [ "autogroup:member" ];
      dst = [
        "autogroup:member"
        "tag:server"
      ];
      ip = [ "tcp:22" ];
    }
    # Deploys build on leviathan, which copies each closure to its machine.
    {
      src = [ "leviathan" ];
      dst = nixosMachines;
      ip = [ "tcp:22" ];
    }
    # Remote builds, as the builders' nix user; daedalus's Linux VM is reached through daedalus.
    {
      src = roleMachines "builders" "client";
      dst = roleMachines "builders" "server";
      ip = [ "tcp:22" ];
    }
    # The Nix cache every machine substitutes from.
    {
      src = [
        "autogroup:member"
        "tag:server"
      ];
      dst = roleMachines "harmonia" "server";
      ip = [ "tcp:5000" ];
    }
    # Prometheus scrapes every machine's node and SMART exporters,
    {
      src = monitoringServers;
      dst = [
        "autogroup:member"
        "tag:server"
      ];
      ip = [
        "tcp:9100"
        "tcp:9633"
      ];
    }
  ]
  # and each machine's own exporters.
  ++ map (name: {
    src = monitoringServers;
    dst = [ name ];
    ip = map (port: "tcp:${toString port}") exporterPorts.${name};
  }) (builtins.filter (name: exporterPorts.${name} != [ ]) (builtins.attrNames exporterPorts))
  ++ [
    # The Alertmanagers gossip, so each alert is sent once.
    {
      src = monitoringServers;
      dst = monitoringServers;
      ip = [
        "tcp:9094"
        "udp:9094"
      ];
    }
    # Every Linux machine ships its journal to Loki on sequoia, and the owner's devices open Grafana there.
    {
      src = [
        "autogroup:member"
        "tag:server"
      ];
      dst = [ "sequoia" ];
      ip = [ "tcp:80" ];
    }
    {
      src = [ "autogroup:member" ];
      dst = [ "sequoia" ];
      ip = [ "tcp:443" ];
    }
    # Shell history sync.
    {
      src = roleMachines "atuin" "client";
      dst = roleMachines "atuin" "server";
      ip = [ "tcp:8888" ];
    }
    # Syncthing peers dial each other by tailnet name.
    {
      src = roleMachines "syncthing" "peer";
      dst = roleMachines "syncthing" "peer";
      ip = [ "tcp:22000" ];
    }
    # mandate: its app on 443, and the agent identities of the owner's machines on its agent port.
    {
      src = [ "autogroup:member" ];
      dst = [ "lachesis" ];
      ip = [
        "tcp:443"
        "tcp:8443"
      ];
    }
    # The public Minecraft streams conduit forwards to leviathan.
    {
      src = [ "conduit" ];
      dst = [ "leviathan" ];
      ip = [
        "tcp:25568"
        "tcp:25573"
        "udp:24457"
        "udp:24460"
      ];
    }
    # Through janus's route to the trusted VLAN: the resolver of the split-DNS names,
    {
      src = [ "autogroup:member" ];
      dst = [ lan.vlans.trusted.gateway ];
      ip = [
        "tcp:53"
        "udp:53"
      ];
    }
    # paperless and leviathan's iDRAC,
    {
      src = [ "autogroup:member" ];
      dst = [
        lan.hosts.${lan.dns.paperless.lan}.ip
        lan.hosts.leviathan-idrac.ip
      ];
      ip = [ "tcp:443" ];
    }
    # and clotho's initrd, which waits there for its disk passphrase.
    {
      src = [ "autogroup:member" ];
      dst = [ lan.hosts.clotho.ip ];
      ip = [ "tcp:2222" ];
    }
    {
      src = [ "autogroup:member" ];
      dst = [ "autogroup:internet" ];
      ip = [ "*" ];
    }
    {
      src = [ "tag:work" ];
      dst = [ "tag:work" ];
      ip = [ "*" ];
    }
    {
      src = [
        "autogroup:member"
        "tag:work"
      ];
      dst = [ "tag:adeci-installer" ];
      ip = [ "*" ];
    }
    # The owner's devices reach every port on leviathan, as shared users do, for services started there by hand.
    {
      src = [ "autogroup:member" ];
      dst = [ "leviathan" ];
      ip = [ "*" ];
    }
    # Users a node is shared with; list each shared-out node in dst.
    {
      src = [ "autogroup:shared" ];
      dst = [ "leviathan" ];
      ip = [ "*" ];
    }
    # Agent machines, e.g. Grok Bot: only mandate's agent port on lachesis, never the owner side.
    {
      src = [ "tag:agent" ];
      dst = [ "lachesis" ];
      ip = [ "tcp:8443" ];
    }
    # MicroVMs: tag:tenant plus a role tag, reachable only as granted here.
    {
      src = [ "autogroup:member" ];
      dst = [ "tag:tenant" ];
      ip = [ "tcp:22" ];
    }
    # Moonlight, also for users a seat is shared with.
    {
      src = [
        "autogroup:member"
        "autogroup:shared"
      ];
      dst = [ "tag:gaming" ];
      ip = [
        "tcp:47984"
        "tcp:47989"
        "tcp:48010"
        "udp:47998-48000"
      ];
    }
  ];

  # Keeps tailnet addresses out of Cloudflare WARP's range.
  nodeAttrs = [
    {
      target = [ "*" ];
      ipPool = [ "100.64.0.0/11" ];
    }
  ];

  tagOwners = {
    "tag:adeci-installer" = [ "autogroup:admin" ];
    "tag:work" = [ "autogroup:admin" ];
    "tag:agent" = [ "autogroup:admin" ];
    "tag:tenant" = [ "autogroup:admin" ];
    "tag:gaming" = [ "autogroup:admin" ];
    "tag:server" = [ "autogroup:admin" ];
  };

  tests = [
    {
      src = owner;
      accept = [
        "${lan.hosts.leviathan-idrac.ip}:443"
        "${lan.hosts.sequoia.ip}:443"
        "tag:adeci-installer:22"
        "lachesis:443"
        "lachesis:8443"
        "sequoia:22"
        "praxis:22"
        "leviathan:5000"
        "sequoia:80"
        "sequoia:443"
        "${lan.vlans.trusted.gateway}:53"
        "${lan.hosts.clotho.ip}:2222"
        # A test can't name autogroup:internet (tailscale/tailscale#4416); a public address stands for it.
        "1.1.1.1:443"
      ];
      deny = [
        "tag:work:22"
        "${lan.vlans.iot.gateway}:80"
        "${lan.hosts.nexus.ip}:80"
      ];
    }
    {
      src = owner;
      proto = "udp";
      accept = [ "${lan.vlans.trusted.gateway}:53" ];
    }
    {
      src = "leviathan";
      accept = [
        "praxis:22"
        "conduit:22"
        "daedalus:22"
      ];
    }
    {
      src = "bramble";
      accept = [
        "daedalus:22"
        "leviathan:22"
      ];
    }
    {
      src = "icarus";
      accept = [
        "daedalus:22"
        "sequoia:8888"
      ];
    }
    {
      src = "tag:server";
      accept = [
        "leviathan:5000"
        "sequoia:80"
      ];
    }
    {
      src = "sequoia";
      accept = [
        "praxis:9100"
        "janus:9633"
        "conduit:9115"
        "janus:9167"
        "janus:9374"
        "janus:9436"
        "janus:9437"
        "janus:9547"
        "leviathan:9400"
        "leviathan:20241"
        "conduit:9094"
        "praxis:22000"
      ];
    }
    {
      src = "conduit";
      accept = [
        "daedalus:9100"
        "sequoia:20241"
        "sequoia:9094"
        "leviathan:25568"
        "leviathan:25573"
      ];
    }
    {
      src = "conduit";
      proto = "udp";
      accept = [
        "sequoia:9094"
        "leviathan:24457"
        "leviathan:24460"
      ];
    }
    {
      src = "praxis";
      accept = [
        "sequoia:8888"
        "sequoia:22000"
        "aegis:22000"
      ];
    }
    # The owner's devices reach no database, exporter or gossip port off leviathan, and through the route only what it serves.
    {
      src = owner;
      deny = [
        "sequoia:5432"
        "praxis:9100"
        "janus:9547"
        "sequoia:9094"
        "${lan.hosts.leviathan.ip}:22"
        "${lan.hosts.sequoia.ip}:21"
      ]
      ++ map (name: "${name}:9100") (builtins.filter (name: name != "leviathan") servers);
    }
    # Servers reach laptops only to scrape, sync and deploy, and open a shell only for deploys and remote builds.
    {
      src = "conduit";
      deny = [
        "${owner}:22"
        "praxis:22000"
        "leviathan:22"
        "sequoia:22"
      ];
    }
    {
      src = "sequoia";
      deny = [
        "${owner}:22"
        "leviathan:22"
      ];
    }
    {
      src = "leviathan";
      deny = [ "icarus:22" ];
    }
    {
      src = "bramble";
      deny = [ "sequoia:22" ];
    }
    {
      src = "tag:server";
      deny = [
        "lachesis:443"
        "${lan.hosts.leviathan-idrac.ip}:443"
        "1.1.1.1:443"
      ];
    }
    {
      src = "tag:work";
      accept = [
        "tag:work:22"
        "tag:adeci-installer:22"
      ];
      deny = [
        "${owner}:22"
        "${lan.hosts.sequoia.ip}:443"
        "${lan.hosts.leviathan-idrac.ip}:443"
      ];
    }
    {
      src = "tag:agent";
      accept = [ "lachesis:8443" ];
      deny = [
        "lachesis:22"
        "lachesis:443"
        "leviathan:22"
        "${lan.hosts.sequoia.ip}:443"
        "tag:work:22"
      ];
    }
    {
      src = owner;
      accept = [
        "tag:tenant:22"
        "tag:gaming:47989"
      ];
    }
    {
      src = "tag:gaming";
      deny = [
        "tag:tenant:22"
        "leviathan:22"
        "lachesis:443"
        "lachesis:8443"
        "${lan.hosts.sequoia.ip}:443"
        "${lan.hosts.leviathan-idrac.ip}:443"
        "${owner}:22"
      ];
    }
    {
      src = owner;
      accept = [ "leviathan:2022" ];
    }
  ];
}

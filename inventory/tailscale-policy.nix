{
  clanInstances,
  lan,
  machines,
  tailnet,
  ...
}:
let
  # Personal tailnet login.
  owner = "alex.decious@gmail.com";

  nixosMachines = builtins.filter (name: machines.${name}.class == "nixos") (
    builtins.attrNames tailnet.addresses
  );

  # Machines an instance gives a role, by name or tag (all, nixos, darwin are clan's).
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

  # Each agent's exporter ports; 9115 is blackbox_exporter for its probes.
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
    # Admin devices reach every machine and deploy as root.
    {
      src = [ "autogroup:member" ];
      dst = [
        "autogroup:member"
        "tag:server"
      ];
      ip = [ "tcp:22" ];
    }
    # Deploys build on leviathan, which copies closures out.
    {
      src = [ "leviathan" ];
      dst = nixosMachines;
      ip = [ "tcp:22" ];
    }
    # Remote builds as the nix user; daedalus's Linux VM goes through daedalus.
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
    # Prometheus scrapes node and SMART exporters everywhere,
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
    # Linux journals go to Loki on sequoia; personal devices open Grafana there,
    # and agents on servers reach raidho.
    {
      src = [
        "autogroup:member"
        "tag:server"
      ];
      dst = [ "sequoia" ];
      ip = [
        "tcp:80"
        "tcp:443"
      ];
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
    # mandate: app on 443, agent port for personal machines' agent identities.
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
    # Via janus's route to trusted: the split-DNS resolver,
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
    # and clotho's initrd, for its disk passphrase.
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
    # Personal devices reach any port on leviathan, like shared users, for ad-hoc services.
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
    # Farid's SSH login on daedalus.
    {
      src = [ "autogroup:shared" ];
      dst = [ "daedalus" ];
      ip = [ "tcp:22" ];
    }
    # raidho's shared port; keeps sequoia:443 off-limits.
    {
      src = [ "autogroup:shared" ];
      dst = [ "sequoia" ];
      ip = [ "tcp:8443" ];
    }
    # Agent machines (e.g. Grok Bot): only mandate's agent port on lachesis.
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
        "sequoia:443"
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
    # No database, exporter or gossip ports off leviathan; via the route only what it serves.
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
    # Servers reach laptops only to scrape, sync, deploy; SSH only for deploys and builds.
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
        "sequoia:8443"
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
        "sequoia:8443"
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
        "sequoia:8443"
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
        "sequoia:8443"
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

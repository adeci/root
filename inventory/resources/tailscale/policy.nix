{ addresses, homelan }:
{
  hosts = {
    inherit (addresses)
      leviathan
      modus
      lachesis
      ;
  };

  grants = [
    {
      src = [ "autogroup:member" ];
      dst = [ "autogroup:member" ];
      ip = [ "*" ];
    }
    {
      src = [ "autogroup:member" ];
      dst = [ homelan.vlans.trusted.cidr ];
      ip = [ "*" ];
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
    # Users a node is shared with; list each shared-out node in dst.
    {
      src = [ "autogroup:shared" ];
      dst = [ "leviathan" ];
      ip = [ "*" ];
    }
    {
      src = [ "autogroup:shared" ];
      dst = [ "modus" ];
      ip = [ "tcp:22" ];
    }
    # Agent machines, e.g. Grok Bot: only mandate's agent port on lachesis,
    # never the owner side.
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
  };

  tests = [
    {
      src = "alex.decious@gmail.com";
      accept = [
        "${homelan.hosts.leviathan-idrac.ip}:443"
        "${homelan.hosts.sequoia.ip}:443"
        "tag:adeci-installer:22"
        "lachesis:443"
      ];
      deny = [
        "tag:work:22"
        "${homelan.vlans.iot.gateway}:80"
        "${homelan.hosts.nexus.ip}:80"
      ];
    }
    {
      src = "tag:work";
      accept = [
        "tag:work:22"
        "tag:adeci-installer:22"
      ];
      deny = [
        "alex.decious@gmail.com:22"
        "${homelan.hosts.sequoia.ip}:443"
        "${homelan.hosts.leviathan-idrac.ip}:443"
      ];
    }
    {
      src = "tag:agent";
      accept = [ "lachesis:8443" ];
      deny = [
        "lachesis:22"
        "lachesis:443"
        "leviathan:22"
        "leviathan:11435"
        "${homelan.hosts.sequoia.ip}:443"
        "tag:work:22"
      ];
    }
    {
      src = "alex.decious@gmail.com";
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
        "${homelan.hosts.sequoia.ip}:443"
        "${homelan.hosts.leviathan-idrac.ip}:443"
        "alex.decious@gmail.com:22"
      ];
    }
  ];
}

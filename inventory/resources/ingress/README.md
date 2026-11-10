# Ingress

Public L4 ingress data for edge machines. Both files are keyed by edge machine name.

## What This Owns

`streams.nix` owns public socket forwarding. Each edge lists its streams:

```nix
{
  name = "minecraft-gab"; # unique per edge
  description = "Minecraft bros gab";
  protocol = "tcp"; # tcp or udp
  listen = 25573; # public port on the edge
  upstream = "leviathan.cymric-daggertooth.ts.net:25573"; # host:port
}
```

A stream forwards its `listen` port to `upstream` and opens that port on the edge's firewalls, including its cloud firewall. Each protocol/port pair binds at most one stream per edge.

`edges.nix` owns edge-machine metadata and the static cloud firewall rules that are not streams, such as HTTP/HTTPS and Tailscale UDP:

```nix
{
  provider = "hcloud"; # cloud whose firewall fronts the edge
  firewall = {
    name = "conduit"; # optional, defaults to the edge name
    staticRules = [
      {
        description = "HTTPS (Zipline)";
        protocol = "tcp"; # tcp or udp
        port = 443;
      }
    ];
  };
}
```

A protocol/port pair appears once across an edge's static rules and streams. SSH is deliberately absent: edges accept it only over Tailscale.

## What This Does Not Own

DNS belongs to the Cloudflare resource. Its records may reference ingress streams for edge IPs and SRV ports, but DNS remains Cloudflare-owned.

Upstream service firewalls stay with the service host: it must explicitly allow any private `tailscale0` ports it serves.

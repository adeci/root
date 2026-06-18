# Ingress

Public L4 ingress data for edge machines.

## What This Owns

`streams.nix` owns public socket forwarding:

```nix
{
  name = "minecraft-hunter";
  description = "Minecraft hunter server";
  protocol = "tcp";
  listen = 25567;
  upstream = "lazarus.tail0e36b8.ts.net:25565";
}
```

Each stream entry is consumed by:

- `modules/nixos/public-edge.nix` for Nginx `stream` proxy config.
- `modules/nixos/public-edge.nix` for the edge machine's NixOS firewall.
- `modules/terranix/hcloud/default.nix` for Hetzner Cloud firewalls on `hcloud` edges.

`edges.nix` owns edge-machine metadata and static cloud firewall rules, such as SSH, HTTP/HTTPS, and Tailscale UDP.

## What This Does Not Own

DNS still lives in `inventory/resources/cloudflare/dns.nix`. Cloudflare records may reference ingress streams for edge IPs and SRV ports, but DNS remains Cloudflare-owned.

Upstream service firewalls still live with the service host. For example, Sequoia or Leviathan must explicitly allow any private `tailscale0` ports they serve.

## Why Nginx Uses Variables

Nginx resolves static `proxy_pass host:port` targets during config test/reload. That breaks deploys when a Tailnet or shared-in Tailscale hostname is temporarily unresolved.

`public-edge.nix` emits variable-backed upstreams instead:

```nginx
resolver 100.100.100.100 valid=30s ipv6=off;
set $upstream_minecraft_hunter_tcp_25567 "lazarus.tail0e36b8.ts.net:25565";
proxy_pass $upstream_minecraft_hunter_tcp_25567;
```

This keeps Nginx reloads independent from current MagicDNS availability while still resolving the upstream at connection time.

## Adding A Public L4 Service

1. Add one entry to `streams.nix` under the edge machine.
2. If it needs DNS, add the A/SRV/CNAME record in `inventory/resources/cloudflare/dns.nix`, referencing the edge or stream as needed.
3. Run `nix eval .#nixosConfigurations.<edge>.config.system.build.toplevel.drvPath`.
4. Run `nix run .#tf-plan` if the edge uses a provider-backed firewall.

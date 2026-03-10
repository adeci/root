# ACME TLS — Replace Cloudflare Tunnels

Status: **not started**

## Why

All public services (buildbot, vaultwarden, adeci.dev, etc.) currently
route through Cloudflare tunnels. This works but has downsides:

- **Cloudflare terminates TLS.** They can inspect all traffic. For a
  password manager (vaultwarden) that's an extra trust dependency we
  don't need.
- **Vendor lock-in.** DNS, tunnel daemon, TLS — all Cloudflare. An
  account issue or policy change takes everything down.
- **Workarounds.** The `X-Forwarded-Proto` redirect for buildbot is a
  symptom: we don't control the TLS layer, so we have to sniff headers
  to enforce HTTPS. With own certs, `forceSSL = true` just works.
- **Opacity.** Harder to debug, harder to reason about. The tunnel is a
  black box between Cloudflare's edge and cloudflared on our machines.

Cloudflare tunnels do provide value (no inbound ports, DDoS protection,
works behind NAT). But for personal infrastructure where we control the
network, ACME certs with direct exposure are simpler, more transparent,
and fully ours.

## What Changes

| Component       | Current                              | Target                                |
| --------------- | ------------------------------------ | ------------------------------------- |
| TLS termination | Cloudflare edge                      | nginx on our machines (ACME certs)    |
| DNS             | Cloudflare (CNAME to tunnel)         | Any provider → A/AAAA to our IPs      |
| Ingress         | cloudflared tunnel → localhost       | Direct HTTPS to nginx                 |
| HTTP redirect   | `X-Forwarded-Proto` hack in nginx    | `forceSSL = true` (native nginx)      |
| Cert management | None (Cloudflare handles it)         | ACME via Let's Encrypt, auto-renewed  |
| DDoS protection | Cloudflare (free tier)               | None (acceptable for personal infra)  |
| NAT traversal   | Cloudflare tunnel (works behind NAT) | Requires public IP or port forwarding |

## Prerequisites

- [ ] Confirm stable public IPs for leviathan and sequoia (or set up
      DDNS if IPs are dynamic)
- [ ] Ensure ports 80 and 443 are reachable from the internet (router
      port forwarding if needed, firewall rules on the machines)
- [ ] Decide on DNS provider (can stay on Cloudflare for DNS-only
      without proxying, or move to something else entirely)

## Implementation Plan

### 1. ACME module

Create `modules/nixos/acme.nix` — shared config for Let's Encrypt cert
provisioning. NixOS has good built-in support via `security.acme`:

```nix
security.acme = {
  acceptTerms = true;
  defaults.email = "...";
};
```

Individual services add their own virtualHost with:

```nix
services.nginx.virtualHosts."buildbot.decio.us" = {
  forceSSL = true;
  enableACME = true;  # per-domain cert
  # or: useACMEHost = "decio.us";  # wildcard cert
};
```

### 2. Wildcard cert vs per-domain

**Per-domain** (simpler): Each virtualHost gets its own cert via HTTP-01
challenge. No DNS provider integration needed. Downside: every new
subdomain needs port 80 open for the challenge.

**Wildcard** (Mic92's approach): One `*.decio.us` cert via DNS-01
challenge. Requires a DNS provider API token for automated validation.
Cleaner if we have many subdomains. Works even if port 80 is blocked.

Recommendation: **start with per-domain**, move to wildcard later if the
number of subdomains grows.

### 3. Migration per service

Migrate one service at a time. For each:

1. Add `forceSSL = true; enableACME = true;` to the nginx virtualHost
2. Open ports 80 + 443 in the NixOS firewall
3. Update DNS from Cloudflare-proxied CNAME to a direct A/AAAA record
4. Remove the service from the cloudflare-tunnel ingress map
5. Deploy and verify HTTPS works end-to-end

Order suggestion: buildbot first (least critical), then adeci.dev, then
vaultwarden last (most sensitive, most important to get right).

### 4. Retire Cloudflare tunnels

Once all services are migrated off a machine's tunnel:

1. Remove the machine from `clan-inventory/instances/cloudflare-tunnel.nix`
2. Remove the cloudflared service
3. Optionally keep Cloudflare for DNS-only (unproxied records)

## Open Questions

- [ ] Are leviathan and sequoia's IPs stable? If behind NAT, is port
      forwarding feasible?
- [ ] Keep Cloudflare as DNS provider (just disable proxying) or move
      DNS elsewhere too?
- [ ] Wildcard cert from the start, or per-domain first?
- [ ] Is DDoS protection worth keeping for any service? (Probably not
      for personal infra, but worth asking.)

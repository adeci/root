# Matrix Homeserver Plan

Self-hosted Matrix homeserver for a personal `@alex:<domain>` identity,
deployed on sequoia via Clan services.

## Why

Stop depending on matrix.org for identity. Own the account, the data,
the domain. Federation means we can still talk to everyone on other
servers.

## Research Summary

### What a Matrix Homeserver Does

A homeserver is the full backend for your Matrix identity. It:

- Stores all messages, room state, encryption keys, and media
- Federates with other Matrix servers (you can talk to @anyone:matrix.org)
- Handles device management, push notifications, key verification
- Serves the client-server API (what Element/Fractal connect to)
- Serves the server-server API (how other homeservers talk to yours)

It's not a relay — it's the authoritative source for your account. Like
running your own email server: messages for your domain land on your box.

### Server Implementations

#### Synapse (Python, reference implementation)

The original, what matrix.org runs. 7+ years of battle-testing.

Strengths:

- Every Matrix spec feature lands here first
- Bridge ecosystem (mautrix-whatsapp, telegram, signal, discord, slack,
  IRC) is built and tested against Synapse specifically
- Full Admin API for user/room/media management
- Horizontal scaling via workers if ever needed
- Mature NixOS module (`services.matrix-synapse`, 1600+ lines)
- SQLite viable for personal use, PostgreSQL upgrade path exists

Downsides:

- Python — ~500MB-1GB RAM for a quiet personal server, more if joining
  large federated rooms
- Weekly-ish release cadence, every upgrade runs DB migrations
- Rollback window is limited (2-8 versions back max)
- Media storage grows unbounded without explicit cleanup
- License changed to AGPL-3.0 (irrelevant for personal self-hosting)

#### Tuwunel (Rust, successor to Conduit → Conduwuit)

The living fork of the lightweight Rust lineage. Packaged in nixpkgs as
`matrix-tuwunel` with `services.matrix-tuwunel` NixOS module.

Strengths:

- Rust — dramatically less RAM/CPU than Synapse
- Embedded RocksDB — no separate database service
- Single binary, simple config
- Swiss government sponsorship, full-time staff
- Bridges work via Appservice API

Downsides:

- **Two predecessor deaths**: Conduit died, Conduwuit archived Jan 2026
- Less battle-tested than Synapse
- Admin API incomplete
- **No migration path FROM Synapse** — starting on Tuwunel locks you in
- Bridge support has "rough edges" per their own roadmap
- Automated testing is a roadmap item, not a reality

#### Recommendation: Synapse

- Bridges matter — self-hosting Matrix without bridging Discord/Signal
  is leaving half the value on the table
- Synapse keeps options open (can't migrate away from Tuwunel easily)
- Rust lineage has had 3 project deaths in 3 years; Synapse isn't going
  anywhere
- Resource cost is manageable for personal use on sequoia
- SQLite to start, PostgreSQL later if needed

### Federation & Domain

Your Matrix identity is `@alex:<server_name>`. This is **permanent** —
federation remembers it forever. Changing it means a new account.

Two approaches:

- `@alex:decio.us` — clean, personal, uses delegation
  (`.well-known/matrix/server` on decio.us points to the actual server)
- `@alex:matrix.decio.us` — simpler setup, no delegation needed, but
  the subdomain is baked into your identity forever

Delegation works via a static JSON file served at
`https://decio.us/.well-known/matrix/server` containing
`{"m.server": "matrix.decio.us:443"}`. The actual Synapse instance runs
on `matrix.decio.us`.

### Ingress

Sequoia already has Cloudflare tunnel. Add routes:

- `matrix.decio.us` → localhost:<synapse_port> (client-server + federation)
- Possibly `decio.us/.well-known/matrix/*` for delegation (or serve
  this from an existing web server on decio.us)

Federation requires the server-server API on port 443 (or delegated).
Cloudflare tunnel handles TLS termination.

**Concern**: Cloudflare is a MITM for federation traffic. Matrix E2EE
protects message content, but metadata (who talks to whom, room
membership) is visible to Cloudflare. This is the same tradeoff as the
other services on sequoia. Acceptable for personal use, worth noting.

### Voice/Video Calls

Requires a TURN server (coturn) for NAT traversal. Can skip initially
and add later — text/bridges are the core value. Coturn needs:

- UDP port range (49000-50000) opened
- TLS certificates
- Shared secret wired into Synapse config

Element Call / group video needs LiveKit (SFU) — even more complexity.
Skip entirely for v1.

### Bridges (Future)

The main ones available in nixpkgs:

- `mautrix-whatsapp` — WhatsApp via linked device
- `mautrix-telegram` — Telegram
- `mautrix-signal` — Signal
- `mautrix-discord` — Discord
- `matrix-appservice-irc` — IRC
- `heisenbridge` — IRC (lighter alternative)

Each bridge runs as its own systemd service with its own database and
generates an appservice registration YAML that must be wired into
Synapse's `app_service_config_files`. Plan for this in the service
design even if we don't deploy bridges on day one.

### Clients

- **Element Desktop** or **Fractal** — the only two with non-deprecated
  encryption (everything else uses the insecure `olm` library)
- **Element Web** — can self-host on sequoia, optional

## Decisions Needed

1. **Domain**: `@alex:decio.us` vs `@alex:adeci.dev` vs something else?
   This is permanent. `decio.us` feels more personal, `adeci.dev` is
   the project/infra domain.

2. **Database**: Start with SQLite (zero ops, good enough for 1-5 users)
   or go straight to PostgreSQL (more robust, required for workers/scale)?

3. **Bridges on day one?** Or just get the homeserver running and add
   bridges later? Bridges add complexity — each is its own service with
   its own DB and registration dance.

4. **Element Web?** Self-host the web client, or just use desktop/mobile
   clients?

5. **Voice/video?** Skip coturn for now, or set it up from the start?

6. **Registration**: Closed (invite-only) or token-gated? Open
   registration gets spammed immediately.

## Proposed Architecture (MVP)

```
                    Cloudflare Tunnel
                          │
           ┌──────────────┼──────────────┐
           │              │              │
    matrix.decio.us  decio.us/.well-known
           │              │
           ▼              ▼
      ┌─────────┐   ┌──────────┐
      │ Synapse  │   │  static  │
      │ (SQLite) │   │  JSON    │
      │ :8008    │   │ delegate │
      └─────────┘   └──────────┘
           │
      sequoia (NixOS)
```

Phase 1: Synapse + SQLite, federation, basic account
Phase 2: Bridges (start with whichever messaging apps are most used)
Phase 3: Coturn for voice/video (if wanted)
Phase 4: PostgreSQL migration (if SQLite becomes a bottleneck)

## Implementation Notes

### Clan Service Pattern

Should follow the existing service pattern in `clan-services/`. See
`clan-services/roster/default.nix` as reference. The Matrix service
would define roles (likely just `server`) and be assigned to sequoia
via a tag in `clan-inventory/instances/`.

### Secrets

Synapse needs several secrets:

- `registration_shared_secret` — for creating accounts via admin API
- `macaroon_secret_key` — for auth tokens
- `form_secret` — for CAPTCHA/forms

These should go through `clan.core.vars` (like tailscale/cloudflare
tokens do), NOT in the Nix store. Synapse supports `extraConfigFiles`
for injecting secrets at runtime.

### Cloudflare Tunnel Addition

Add to `clan-inventory/instances/cloudflare-tunnel.nix`:

```nix
{
  hostname = "matrix.decio.us";
  service = "http://localhost:8008";
}
```

And delegation endpoint if using `decio.us` as the server name.

## References

- NixOS Wiki: https://wiki.nixos.org/wiki/Matrix
- Synapse docs: https://element-hq.github.io/synapse/latest/
- Synapse NixOS module: `services.matrix-synapse`
- Tuwunel (if reconsidering): `services.matrix-tuwunel` in nixpkgs
- Matrix spec (federation): https://spec.matrix.org/latest/server-server-api/
- `.well-known` delegation: https://spec.matrix.org/latest/client-server-api/#well-known-uri

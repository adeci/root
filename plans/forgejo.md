# Forgejo — Self-Hosted Git Forge

Status: **not started**

## Why

GitHub is the primary home for public repos — discoverability, FOSS
collaboration, nixpkgs work, activity graph. That doesn't change. But
having code exist only on GitHub means depending entirely on their
availability and policies.

Forgejo gives us:

- **Sovereignty.** A full copy of everything we care about, under our
  control.
- **Private repos without GitHub's rules.** Experiments, personal tools,
  half-baked ideas, infra config that doesn't belong public.
- **CI for private work.** buildbot-nix already supports the Gitea API
  (which Forgejo implements identically) — private repos get the same CI
  pipeline as public ones.
- **Webhook integrations.** Wire up OpenCrow, buildbot, or whatever else
  to forge events without going through GitHub's infrastructure.

## Research Summary

### What others do

**Mic92 — Radicle** (decentralized, P2P). Runs Radicle nodes on 3
machines (eve, eva, blob64) that peer with each other. Built a custom
GitHub→Radicle sync system: GitHub Actions SSH into his Radicle node to
push updates. Auto-seeds repos from followed users. Has a web UI at
radicle.thalheim.io. Impressive engineering, but a lot of custom
machinery (sync scripts, socket-activated daemons, multi-node peering)
for what amounts to a P2P backup. Good if you care about
decentralization ideologically, overkill otherwise.
Source: `~/git/pi-repos/Mic92--dotfiles`, `nixosModules/radicle-*.nix`

**Lassulus — cgit + gitolite** (krebs ecosystem). Uses `krebs.git` from
the stockholm framework — gitolite for access control, cgit for the web
frontend. Hosted at cgit.lassul.us. Has IRC post-receive hooks, supports
restricted repos with per-user collaborator access. Deeply tied to the
krebs ecosystem, not portable.
Source: `~/git/pi-repos/Lassulus--superconfig`, `2configs/git.nix`

**pinpox — Gitea**. Self-hosted at git.0cx.de. Clean NixOS module:
Caddy reverse proxy, registration disabled, sign-in required, SMTP
mailer, restic backups. Uses `services.gitea` (not Forgejo) due to
historical inertia — set it up before the fork, never migrated. nixpkgs
still ships both as full separate modules.
Source: `~/git/pi-repos/pinpox--nixos`, `modules/gitea/default.nix`

**turbio — cgit** (minimal). Bare git repos on a ZFS dataset, cgit
scans the directory and serves a read-only web UI at git.turb.io. Six
lines of NixOS config. No access control, no forge features — just SSH
push + web viewer.
Source: `~/git/pi-repos/turbio--dotfiles`, `hosts/ballos/configuration.nix`

### Why Forgejo over alternatives

- **vs Gitea**: Forgejo is the community fork with better governance.
  Same codebase, NixOS has `services.forgejo` upstream. The Nix
  community has largely moved to Forgejo. Pinpox's Gitea is inertia.
- **vs Radicle**: Cool tech, but enormous complexity for P2P redundancy
  we don't need. We just want a forge we control.
- **vs cgit/gitolite**: Read-only viewer, no forge features. Fine for
  "look at my repos" but doesn't add utility.
- **vs Sourcehut/GitLab**: Sourcehut is opinionated and email-driven.
  GitLab is massive overkill. Forgejo hits the sweet spot.

### buildbot-nix compatibility

Confirmed: buildbot-nix's "Gitea integration" talks to the standard
`/api/v1/` REST API that Forgejo implements with full compatibility.
Endpoints used: `/api/v1/user/repos`, `/api/v1/repos/{owner}/{repo}/topics`,
`/api/v1/repos/{owner}/{repo}/hooks`. The `buildbot-gitea` plugin
(maintained by Mic92) uses OAuth, webhook, and status push interfaces
that Forgejo supports identically. The NixOS module just takes an
`instanceUrl` — point it at Forgejo and it works.
Source: `~/git/pi-repos/nix-community--buildbot-nix`,
`buildbot_nix/buildbot_nix/gitea_projects.py`, `nixosModules/master.nix`

### Codeberg as reference

Codeberg.org is the largest public Forgejo instance. Good place to see
the UI in action: https://codeberg.org/forgejo/forgejo

## Architecture

### Repo ownership model

| Repo type          | Primary (push to) | Secondary (auto-mirror) |
| ------------------ | ----------------- | ----------------------- |
| Public / FOSS      | GitHub            | Forgejo (pull mirror)   |
| Private / personal | Forgejo           | —                       |

GitHub activity graph requires direct pushes — mirrored commits don't
count. So GitHub stays the push target for anything public.

Forgejo's built-in mirror feature pulls from GitHub on a schedule
(default 8h, configurable). Give it a GitHub token and it handles the
rest.

### Infrastructure

Forgejo runs on **sequoia**, which already has:

- nginx (for Matrix reverse proxy)
- PostgreSQL (for Matrix Synapse)
- Cloudflare tunnel ingress
- restic backups (via pinpox-style restic-client, used by other services)

Add `git.decio.us` as a new Cloudflare tunnel entry pointing to
Forgejo's HTTP port.

### CI integration

buildbot-nix on leviathan is already wired to GitHub for public repos.
For private repos on Forgejo, add a second buildbot-nix backend pointing
at the Forgejo instance. Both can coexist — buildbot-nix supports
multiple project sources.

## Implementation Plan

### 1. Create the Forgejo module

`machines/sequoia/modules/forgejo.nix` — machine-specific since it's
tied to sequoia's domains, tunnel, and backup config.

Reference pinpox's Gitea module for structure, adapted for Forgejo:

```nix
{ config, ... }:
let
  host = "git.decio.us";
  httpPort = 3000;
in
{
  services.forgejo = {
    enable = true;
    database.type = "postgres";
    settings = {
      server = {
        ROOT_URL = "https://${host}";
        HTTP_PORT = httpPort;
        HTTP_ADDR = "127.0.0.1";
        DOMAIN = host;
      };
      service = {
        DISABLE_REGISTRATION = true;
        REQUIRE_SIGNIN_VIEW = false;  # public repos should be browsable
      };
      # SMTP mailer — configure if we want email notifications
    };
  };

  # Reverse proxy via existing nginx
  services.nginx.virtualHosts."forgejo" = {
    listen = [{ addr = "127.0.0.1"; port = <pick a port>; }];
    locations."/".proxyPass = "http://127.0.0.1:${toString httpPort}";
    # proxy headers, client_max_body_size for push, etc.
  };

  # Backups
  # Add /var/lib/forgejo to restic backup paths
}
```

Key decisions to make during implementation:

- **nginx port for tunnel ingress**: Follow the pattern from matrix.nix
  (Synapse uses 8448, well-known uses 8748). Pick an unused port for
  the Forgejo nginx vhost that the Cloudflare tunnel will hit.
- **`REQUIRE_SIGNIN_VIEW`**: `false` means mirrored public repos are
  browsable without login. Feels right — it's a public-facing forge.
- **PostgreSQL**: Forgejo can share the existing PostgreSQL instance
  (separate database). The NixOS module handles DB creation via
  `services.forgejo.database.type = "postgres"`.
- **Secrets**: Admin account password, maybe an API token for setting
  up mirrors programmatically. Use clan.core.vars like other services.

### 2. Add Cloudflare tunnel entry

In `clan-inventory/instances/cloudflare-tunnel.nix`, add to sequoia's
ingress:

```nix
"git.decio.us" = "http://localhost:<nginx-port>";
```

### 3. DNS

Add a `git.decio.us` CNAME pointing to the Cloudflare tunnel, same as
the other `*.decio.us` subdomains.

### 4. Initial setup

After deploy:

- Create admin account (via CLI or first-run, registration is disabled
  so use `forgejo admin user create`)
- Generate API token for mirror management
- Set up GitHub pull mirrors for key repos (can be done via web UI or
  API)

### 5. Wire up buildbot-nix (future)

Once Forgejo is stable and has private repos worth building, add the
Forgejo backend to leviathan's buildbot-nix config. This is a separate
task — get the forge running first.

## Open Questions

- [ ] SMTP mailer — do we want email notifications from Forgejo? If so,
      need to configure a mail relay.
- [ ] Which GitHub repos to mirror initially? All public repos, or just
      a curated set?
- [ ] Mirror schedule — default 8h is fine, or more frequent?
- [ ] Should mirrored repos be publicly browsable (`REQUIRE_SIGNIN_VIEW
    = false`) or private by default?
- [ ] Backup strategy — restic path for `/var/lib/forgejo`, or also
      dump PostgreSQL separately?
- [ ] Domain: `git.decio.us` feels right. Any other preference?

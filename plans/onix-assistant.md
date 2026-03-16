# Onix — Personal AI Assistant

Personal AI assistant running on sequoia via OpenCrow, communicating over
Matrix as `@onix:decio.us`. Powered by pi with Claude subscription (OAuth).

## Status

- [x] OpenCrow deployed on sequoia (systemd-nspawn container)
- [x] Matrix integration working (@onix:decio.us ↔ @alex:decio.us)
- [x] OAuth auth (Claude subscription, not API credits)
- [x] Skills: kagi-search, context7, web (curl/w3m)
- [x] SOUL.md personality configured
- [x] Allowed users locked to @alex:decio.us
- [ ] Profile picture for Onix

## Phase 1 — Calendar

Wire up vdirsyncer + khal for both accounts.

### Prerequisites

- [ ] Gmail app password (myaccount.google.com → Security → App passwords)
- [ ] Fastmail app password (Settings → Privacy & Security → App Passwords)

### Components

- **vdirsyncer** — syncs Google Calendar + Fastmail CalDAV to local .ics
- **khal** — CLI calendar viewer/manager
- **todoman** — task/reminder management
- Calendar skill teaching Onix how to use khal/todoman
- Credentials via clan vars + mock rbw pattern (like kagi)

### Config files needed

- `machines/sequoia/modules/opencrow/calendar.nix`
- `machines/sequoia/modules/opencrow/skills/calendar/SKILL.md`
- vdirsyncer config (two accounts: Gmail CalDAV + Fastmail CalDAV)
- khal config

### Reference

Mic92's implementation: `Mic92--dotfiles/machines/eve/modules/opencrow/calendar.nix`

## Phase 2 — Email (read-only)

Pull both inboxes locally for search and reading. Onix reads, never
modifies remotely without permission.

### Components

- **mbsync (isync)** — IMAP sync to local Maildir (Gmail + Fastmail)
- **mblaze** — read/search Maildir
- **notmuch** — index and search across both accounts
- Email skill teaching Onix mblaze/notmuch usage
- Bind-mount Maildir into container (read-only initially)

### Accounts

- Gmail: alex.decious@gmail.com
- Fastmail: alex@decio.us (personal business, domain stuff)

### Reference

Mic92's implementation: `Mic92--dotfiles/machines/eve/modules/opencrow/mail.nix`

## Phase 3 — Heartbeat / Morning Briefing

Periodic wake-up for proactive check-ins.

### Config

```nix
OPENCROW_HEARTBEAT_INTERVAL = "8h";
```

### HEARTBEAT.md contents

- Sync calendars, list today's events
- Check for unread important emails (not newsletters)
- Weather forecast
- Weekly (Monday): inbox health report

## Phase 4 — Email Actions (permission-gated)

Onix can act on email but ONLY after explicit user approval.

### Capabilities

- **Draft replies** — writes draft, stores in IMAP Drafts for review
- **Archive** — moves messages from Inbox to Archive (mbsync two-way sync)
- **Unsubscribe** — hits List-Unsubscribe headers via curl
- **Inbox reports** — categorize unread, flag stale newsletters

### Permission model

Onix NEVER acts on email autonomously. Flow:

1. Onix scans and builds a report
2. Messages report to Matrix
3. User reviews and approves specific actions
4. Then Onix executes

### Reference

Mic92's n8n-hooks draft pattern: `Mic92--dotfiles/machines/eve/modules/opencrow/mail.nix`

## Phase 5 — Knowledge Base

Onix accumulates knowledge in markdown files over time.

### Structure

```
/var/lib/opencrow/knowledge/
  people/
  recipes/
  travel/
  projects/
  reference/
```

Onix writes files on request ("remember X", "save this"), searches
them when asked. Git for history. Optionally point Obsidian at the
directory for a UI.

## Future Ideas

- **Voice input** — whisper.cpp transcription of Element voice messages
- **Voice output** — TTS responses (ElevenLabs or local)
- **Infra monitoring** — cron jobs pipe alerts to trigger pipe
- **Bind-mount repos** — light coding from phone (scoped risk)
- **Paperless-ngx** — document management (receipts, invoices, etc.)
- **Move to VPS** — sequoia is in-home, power outage = downtime

## Architecture

```
Alex (Element/phone)
  ↕ Matrix (@alex:decio.us ↔ @onix:decio.us)
sequoia (Synapse)
  └─ systemd-nspawn container "opencrow"
       ├─ opencrow (Go binary, message bridge)
       ├─ pi (RPC subprocess, Claude via OAuth)
       ├─ skills (kagi, context7, web, calendar, email...)
       ├─ /var/lib/opencrow/sessions/ (persistent state)
       └─ /var/lib/opencrow/knowledge/ (knowledge base)
```

## Key Files

```
machines/sequoia/modules/opencrow/
  default.nix       # core config
  soul.md           # personality
  kagi.nix          # web search credentials
  calendar.nix      # (phase 1) calendar sync
  mail.nix          # (phase 2) email sync
  skills/
    calendar/SKILL.md
    email/SKILL.md
```

## Commands

```
!help     — show available commands
!restart  — fresh pi session
!stop     — abort current operation
!compact  — compress context to save tokens
!skills   — list loaded skills
!verify   — set up E2EE cross-signing
```

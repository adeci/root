# @adeci/monitoring

Observability stack for the adeci-net fleet. One server (sequoia) runs
Prometheus + Loki + Grafana behind nginx; every machine tagged `adeci-net`
runs a Grafana Alloy agent that pushes metrics and journal logs over
Tailscale.

## Architecture

```
┌──────────────────────────── server ────────────────────────────┐
│   Prometheus ← remote_write ─┐     ┌─ loki push → Loki         │
│        │                     │     │               │           │
│        └────────┬────────────┴─────┴───────┬───────┘           │
│                 ▼                          ▼                   │
│              Grafana  (PostgreSQL backend, subpath /grafana/)  │
│                      ▲                                         │
│                      │  basic auth + Tailscale-scoped firewall │
│                      │                                         │
│                   nginx  ← virtualHost ${host} on tailscale0   │
└────────────────────────────────────────────────────────────────┘
        ▲                                               ▲
        │ metrics                                 logs  │
        │ (/prometheus/api/v1/write)    (/loki/loki/api/v1/push)
        │                                               │
        └─── Alloy (agent) on every adeci-net machine ──┘
```

## Roles

### `server`

Exactly one machine. Runs Prometheus + Loki + Grafana + nginx.

| Setting               | Default  | Description                                                          |
| --------------------- | -------- | -------------------------------------------------------------------- |
| `host`                | required | FQDN (Tailscale MagicDNS name) every agent uses to reach the server. |
| `grafana.enable`      | `true`   | Run Grafana and provision the Prometheus/Loki datasources.           |
| `retentionDays`       | `30`     | Prometheus TSDB retention in days.                                   |
| `loki.retentionHours` | `168`    | Loki log retention in hours (168h = 7 days).                         |

Push endpoints (`/prometheus/`, `/loki/`) sit behind nginx basic auth whose
credentials are shared with every agent via the perMachine generators. nginx
is only reachable over Tailscale (`networking.firewall.interfaces.tailscale0.
allowedTCPPorts = [ 80 ]`), Grafana is served at `${host}/grafana/` with
anonymous Admin access — the tailnet is the auth boundary.

### `agent`

Every adeci-net machine. Ships metrics + journal logs.

| Setting                | Default | Description                                                                                          |
| ---------------------- | ------- | ---------------------------------------------------------------------------------------------------- |
| `extraCollectors`      | `[]`    | Extra `prometheus.exporter.unix` collectors on top of the defaults.                                  |
| `useSSL`               | `false` | Use HTTPS when talking to the server.                                                                |
| `scrapeInterval`       | `"15s"` | Local scrape interval.                                                                               |
| `extraLabels`          | `{}`    | Extra external labels applied to all metrics + logs (e.g. `{ role = "router"; }`).                   |
| `journal.mode`         | `"all"` | `"all"`, `"nixos"` (services explicitly enabled via NixOS), or `"explicit"` (see `journal.include`). |
| `journal.include`      | `[]`    | Explicit service list when `journal.mode = "explicit"`. Omit the `.service` suffix.                  |
| `journal.relabelRules` | `[]`    | Extra Alloy `rule` blocks appended to `loki.relabel "journal"`.                                      |

Every agent runs these thirteen `prometheus.exporter.unix` collectors by
default: `cpu`, `meminfo`, `filesystem`, `diskstats`, `netdev`, `netclass`,
`loadavg`, `stat`, `uname`, `systemd`, `pressure`, `hwmon`, `textfile`. The
`textfile` collector reads `/var/lib/alloy/textfile/*.prom`, so machine-
specific modules can add custom metrics without editing this service.

Host identity lives in the standard Prometheus `instance` label (set to the
machine's short hostname). Alloy's unix exporter populates it automatically
for node metrics; `alloy_self` overrides the listen-address default so that
Alloy's own metrics carry the hostname too. Loki journal logs get `instance`
from `__journal__hostname`. Alerts, dashboards, and community node-exporter
dashboards can all query `{instance="$host"}` directly.

## Inventory example

```nix
# inventory/clan/instances/monitoring.nix
{
  monitoring = {
    module = { name = "@adeci/monitoring"; input = "self"; };
    roles = {
      agent = {
        tags = [ "adeci-net" ];
        machines.janus.settings = {
          extraCollectors = [ "conntrack" ];
          extraLabels.role = "router";
        };
      };
      server.machines.sequoia.settings = {
        host = "sequoia.cymric-daggertooth.ts.net";
      };
    };
  };
}
```

## Generators

- `prometheus-auth`, `loki-auth` (perMachine, shared) — one htpasswd pair per
  endpoint. Alloy reads the password via systemd `LoadCredential`, nginx
  reads the htpasswd file via `basicAuthFile`. Username is `alloy`.

## Self-monitoring

Every agent scrapes Alloy's own `/metrics` endpoint (`127.0.0.1:12345`) and
pushes it to Prometheus, so `prometheus_remote_write_samples_failed_total` is
available fleet-wide. The server additionally scrapes itself and Loki. The
built-in alert rules fire on `HostStale`, `DiskSpaceHigh`/`Critical`,
`InodeExhaustionHigh`, `SystemdUnitFailed`, `AlloyWriteFailing`,
`PrometheusIngestBroken`, and `LokiIngestBroken`. Notifications are visible
on the Prometheus alerts page and in Grafana.

## Dashboards

Dashboards are **not** provisioned from JSON — they're managed through the
Grafana UI and persisted in PostgreSQL (already covered by the
`clan.core.state.monitoring.folders` backup set via `clan.core.postgresql`).

Recommended community imports (Dashboards → New → Import → paste ID):

- `1860` — Node Exporter Full. Drop-in with our `instance`-labelled metrics.
- `13639` — Logs / App (Loki).
- `20398` — Grafana Alloy overview.

Add your own with Dashboards → New → New dashboard. Changes survive
Grafana restarts because they live in the provisioned postgres DB.

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
| `grafana.enable`      | `true`   | Provision Grafana dashboards and datasources.                        |
| `retentionDays`       | `30`     | Prometheus TSDB retention in days.                                   |
| `loki.retentionHours` | `168`    | Loki log retention in hours (168h = 7 days).                         |

Push endpoints (`/prometheus/`, `/loki/`) sit behind nginx basic auth whose
credentials are shared with every agent via the perMachine generators. nginx
is only reachable over Tailscale (`networking.firewall.interfaces.tailscale0.
allowedTCPPorts = [ 80 ]`), Grafana is served at `${host}/grafana/`.

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
  reads the htpasswd file via `basicAuthFile`.
- `grafana-admin` (server, prompted username + random password) —
  the Grafana web UI login.
- `grafana-secret` (server, random hex) — Grafana session signing key.

## Self-monitoring

Every agent scrapes Alloy's own `/metrics` endpoint (`127.0.0.1:12345`) and
pushes it to Prometheus, so `prometheus_remote_write_samples_failed_total` is
available fleet-wide. The server additionally scrapes itself and Loki. The
built-in alert rules fire on `HostStale`, `DiskSpaceHigh`/`Critical`,
`InodeExhaustionHigh`, `SystemdUnitFailed`, `AlloyWriteFailing`,
`PrometheusIngestBroken`, and `LokiIngestBroken`. Notifications are visible
on the Prometheus alerts page and in Grafana.

## Dashboards

- `fleet-overview.json` — machine status, CPU/memory/disk, systemd units,
  network traffic, load, temperatures, uptime.
- `log-explorer.json` — log volume, top-noisy-services, warning/error
  streams, live log tail.

Add more dashboards by dropping `.json` files into `dashboards/`. Grafana
picks them up on the next restart.

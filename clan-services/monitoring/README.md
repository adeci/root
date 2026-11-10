# @adeci/monitoring

Observability stack for a clan. One server runs Prometheus + Loki + Grafana
behind nginx; every agent machine runs a Grafana Alloy agent that pushes
metrics and journal logs over Tailscale.

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
        └─── Alloy (agent) on every monitored machine ──┘
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
allowedTCPPorts = [ 80 ]`). Grafana uses anonymous Editor access while the
Atlas pages are being designed; the tailnet is the auth boundary and
provisioned dashboards are still managed from git.

### `agent`

Every monitored machine. Ships metrics + journal logs.

| Setting                | Default | Description                                                                                          |
| ---------------------- | ------- | ---------------------------------------------------------------------------------------------------- |
| `extraCollectors`      | `[]`    | Extra `prometheus.exporter.unix` collectors on top of the defaults.                                  |
| `useSSL`               | `false` | Use HTTPS when talking to the server.                                                                |
| `scrapeInterval`       | `"15s"` | Local scrape interval.                                                                               |
| `extraScrapeTargets`   | `[]`    | Extra local Prometheus jobs, such as sidecar Kea or Unbound exporters.                               |
| `extraLabels`          | `{}`    | Extra external labels applied to all metrics + logs (e.g. `{ role = "router"; }`).                   |
| `journal.mode`         | `"all"` | `"all"`, `"nixos"` (services explicitly enabled via NixOS), or `"explicit"` (see `journal.include`). |
| `journal.include`      | `[]`    | Explicit service list when `journal.mode = "explicit"`. Omit the `.service` suffix.                  |
| `journal.relabelRules` | `[]`    | Extra Alloy `rule` blocks appended to `loki.relabel "journal"`.                                      |

Every agent runs these thirteen `prometheus.exporter.unix` collectors by
default: `cpu`, `meminfo`, `filesystem`, `diskstats`, `netdev`, `netclass`,
`loadavg`, `stat`, `uname`, `systemd`, `pressure`, `hwmon`, `textfile`. The
`textfile` collector reads `/var/lib/alloy/textfile/*.prom`, so machine-
specific modules can add custom metrics without editing this service.

A router, for example, can publish its probe results and nftables counters
there. Keep such labels bounded: per-IP and per-port detail belongs in Loki
logs, not Prometheus labels.

Host identity lives in the standard Prometheus `instance` label (set to the
machine's short hostname). Alloy's unix exporter populates it automatically
for node metrics; `alloy_self` overrides the listen-address default so that
Alloy's own metrics carry the hostname too. Loki journal logs get `instance`
from `__journal__hostname`. Alerts and dashboards can query `{instance="$host"}`
directly.

`journal.mode` tiers log volume per machine: core infrastructure can ship the
full journal while other machines ship explicit units only (for example
`alloy`, `sshd`, and the Tailscale units). Failed unit metrics still cover the
whole system via the node exporter. Kernel messages, such as firewall drop
logs, have no systemd unit, so only `journal.mode = "all"` ships them.

## Inventory example

```nix
{
  monitoring = {
    module = { name = "@adeci/monitoring"; input = "self"; };
    roles = {
      agent = {
        tags = [ "all" ];
        machines.router.settings = {
          extraCollectors = [ "conntrack" ];
          extraLabels.role = "router";
          extraScrapeTargets = [
            { job = "kea-dhcp4"; target = "127.0.0.1:9547"; }
            { job = "unbound"; target = "127.0.0.1:9167"; }
            { job = "smokeping"; target = "127.0.0.1:9374"; }
          ];
        };
      };
      server.machines.monitor.settings = {
        host = "monitor.example.ts.net";
      };
    };
  };
}
```

## Generators

- `prometheus-auth`, `loki-auth` (perMachine, shared) — one htpasswd pair per
  endpoint. Alloy reads the password via systemd `LoadCredential`, nginx
  reads the htpasswd file via `basicAuthFile`. Username is `alloy`.
- `alertDelivery.ntfy.configGenerator` (default `ntfy-alerts`) — not created by
  this service. The server machine must define it with an
  `alertmanager-ntfy.yml` that gives the bridge a write-only ntfy token.

## Self-monitoring

Every agent scrapes Alloy's own `/metrics` endpoint (`127.0.0.1:12345`) and
pushes it to Prometheus, so `prometheus_remote_write_samples_failed_total` is
available fleet-wide. The server additionally scrapes itself and Loki. The
built-in Prometheus alert rules cover `HostStale`, `DiskSpaceHigh`/`Critical`,
`InodeExhaustionHigh`, `SystemdUnitFailed`, `AlloyWriteFailing`,
`PrometheusIngestBroken`, and `LokiIngestBroken`.

An additional `router-health` rule group covers low-noise router alerts: core
service down, telemetry/exporter degradation, systemd degraded, stale firewall
counter collection, WAN/internet/DNS probe failure, severe packet loss, high
latency, high CPU/NVMe temperature, root filesystem full, conntrack pressure,
and sustained interface errors. Data-plane and WAN outage alerts are critical;
telemetry-only failures are warnings. Firewall drop counters and logs are not
alert sources. Unlike the rest of the service, these rules (and the dashboard
below) are still written for one specific router: they select
`instance="janus"` and the probe, RouterOS and firewall-counter metrics that
machine publishes.

## Alert Delivery

The monitoring service owns Alertmanager routing and the `alertmanager-ntfy`
bridge. The notification backend is injected through
`settings.alertDelivery.ntfy`: an ntfy server at `baseUrl` (by default one on
the monitoring server itself) and the generator described above.

- `alertmanager-ntfy` listens on `127.0.0.1` and formats Alertmanager webhooks
  into ntfy messages.
- Alertmanager routes only `severity="critical"` to ntfy. Warnings stay visible
  in Prometheus/Grafana but do not notify.
- The bridge receives its ntfy token from the configured clan vars generator, so
  notification credentials do not enter the Nix store.

## Dashboards

The curated Atlas dashboard is provisioned from this service's `dashboards/`
directory and placed in the `Atlas` folder. Grafana's home dashboard is the
`Network` page, not the upstream welcome screen. Provisioned dashboards are
read-only in the UI so production matches the repo.

Current page:

- `Network / Router` — router status (the `janus` instance), WAN/VLAN throughput, high-frequency internet latency/loss percentiles from Smokeping, DHCP leases/pool usage, Unbound resolver status/queries per second/cache/RCODE/query-type/latency/request-list/memory, RouterOS reachability latency, interface drops/errors, conntrack pressure, nftables firewall counter rates, and recent rate-limited firewall drop logs.

Use `Save as` for scratch UI experiments. Promote useful panels back into git.

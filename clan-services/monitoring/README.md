# Monitoring

Collects metrics and journal logs from every agent into Prometheus and Loki on
one server, shows them in Grafana, and sends alerts to ntfy.

## Roles

- `server` (NixOS only, one per instance): runs Prometheus, Alertmanager, Loki
  and Grafana behind nginx, serving Grafana at `http://<host>/grafana/`. Its
  firewall opens nginx only on the Tailscale interface, and the push endpoints
  use basic auth with generated credentials shared with the agents.
- `agent` (NixOS only): runs Grafana Alloy, which pushes node metrics, journal
  logs and its own metrics to the server, plus the endpoints machine modules
  list in the `monitoring.scrapeTargets` NixOS option and the `*.prom` files
  they write to `monitoring.textfileDirectory`. Machines with ACME certificates
  also export when those expire.

## Notes

- Every alert becomes its own ntfy notification: critical ones at high
  priority, warnings at default priority. When an alert resolves, its
  notification is replaced by a silent one, and while a machine is down its
  other alerts are held back.
- The server can't alert about its own outage.
- Grafana grants anonymous Editor access, so the tailnet is the auth boundary.
  Provisioned dashboards are read-only: experiment with Save as and promote
  changes to git.

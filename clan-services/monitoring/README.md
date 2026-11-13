# Monitoring

Collects metrics and journal logs from every agent into Prometheus and Loki on
one server, shows them in Grafana, and sends alerts to ntfy.

## Roles

- `server` (NixOS, one per instance): runs Prometheus, Alertmanager, Loki and
  Grafana behind nginx, which the firewall opens only on the Tailscale
  interface. Grafana is at `http://<host>/grafana/`; agents push to
  `/prometheus/` and `/loki/` with generated basic auth credentials.
- `agent` (NixOS): runs Grafana Alloy, which pushes node metrics, journal logs,
  its own metrics and ACME certificate expiry to the server. Machine modules add
  local endpoints through the `monitoring.scrapeTargets` option and `*.prom`
  files through `monitoring.textfileDirectory`.

## Notes

- Each alert is its own ntfy notification, at high priority when critical. A
  resolved alert's notification is replaced by a silent one, and while a
  machine is down its other alerts are held back.
- The server can't alert about its own outage.
- Grafana grants anonymous Editor access, so the tailnet is the auth boundary.
  Provisioned dashboards are read-only: use Save as and promote changes to git.

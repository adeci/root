# Monitoring

Collects metrics and journal logs from every agent into Prometheus and Loki on
one server, and shows them in Grafana.

## Roles

- `server` (NixOS only, one per instance): runs Prometheus, Loki and Grafana
  behind nginx, serving Grafana at `http://<host>/grafana/`. Its firewall opens
  nginx only on the Tailscale interface, and the push endpoints use basic auth
  with generated credentials shared with the agents.
- `agent` (NixOS only): runs Grafana Alloy, which pushes node metrics, journal
  logs and its own metrics to the server, plus any `*.prom` files other modules
  write to `/var/lib/alloy/textfile/`.

## Notes

- Grafana grants anonymous Editor access, so the tailnet is the auth boundary.
  Provisioned dashboards are read-only: experiment with Save as and promote
  changes to git.
- With `alertDelivery.ntfy.enable`, only critical alerts notify, through the
  ntfy server at `baseUrl`, which this service does not run. The server machine
  must define the `configGenerator` vars generator with an
  `alertmanager-ntfy.yml` holding a write-only ntfy token.
- The router alert rules and the bundled dashboard still target one specific
  router's metrics.

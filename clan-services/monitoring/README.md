# Monitoring

Prometheus on one server scrapes every agent's node_exporter over the tailnet,
Loki keeps their journals, Grafana shows both, and alerts go to ntfy.

## Roles

- `server` (NixOS, one per instance): runs Prometheus, Alertmanager, Loki and
  Grafana behind nginx, which the firewall opens only on the Tailscale
  interface. Prometheus scrapes each agent at `<machine>.<agentDomain>`.
  Grafana is at the root of `grafana.domain`; agents push their journal to
  `/loki/loki/api/v1/push` on `<host>`, the only Loki path open to them, with
  a generated basic auth credential.
- `agent` (NixOS and macOS): runs node_exporter, open to the server on the
  Tailscale interface. A machine lists its other exporters by job and port in
  the agent's `exporters` setting, which its modules read back as
  `monitoring.exporters`, and writes `*.prom` files to
  `monitoring.textfileDirectory`. On NixOS, Vector ships the journal to Loki
  and buffers it on disk while the server is out of reach; a Mac has no
  journal, so it serves metrics only.

## Notes

- Each alert is its own ntfy notification, at high priority when critical. A
  resolved alert's notification is replaced by a silent one, and while a
  machine is down its other alerts are held back.
- The server can't alert about its own outage, and while notifications fail to
  send, the alert for that shows only on the fleet page.
- Grafana has its own login: user `admin`, password from
  `clan vars get <server> grafana-admin/password`. Provisioned dashboards are
  read-only: use Save as and promote changes to git.

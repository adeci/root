# Monitoring

Prometheus on one server scrapes every agent's node_exporter over the tailnet,
Loki keeps their journals, Grafana shows both, and alerts go to ntfy. A backup
server watches the same fleet and alerts when the main one cannot.

## Roles

- `server` (NixOS): the main server runs Prometheus, Alertmanager, Loki and
  Grafana behind nginx, reached over the tailnet. Prometheus scrapes each
  agent at `<machine>.<agentDomain>`.
  Grafana is at the root of `grafana.domain`; agents push their journal to
  `/loki/loki/api/v1/push` on `<host>`, the only Loki path open to them, with
  a generated basic auth credential. A server with `backup = true` runs only
  Prometheus and Alertmanager, on the same agents and rules, and notifies
  through its own ntfy.
- `agent` (NixOS and macOS): runs node_exporter, open to the server on the
  Tailscale interface. A machine lists its other exporters by job and port in
  the agent's `exporters` setting, which its modules read back as
  `monitoring.exporters`, and writes `*.prom` files to
  `monitoring.textfileDirectory`. On NixOS, Vector ships the journal to Loki
  and buffers it on disk while the server is out of reach; a Mac has no
  journal, so it serves metrics only. A NixOS agent with restic backups asks
  each repository for its newest snapshot every hour, which BackupStale goes
  by. One with `probes` runs blackbox_exporter, which requests each address
  when a server scrapes it, once a minute.

## Notes

- Each alert is its own ntfy notification, at high priority when critical. A
  resolved alert's notification is replaced by a silent one, and while a
  machine is down its other alerts are held back. Tapping one opens the fleet
  page on the main server's Grafana, which must be on HTTPS once there is a
  backup server.
- The servers' Alertmanagers form a cluster over the tailnet, so each alert is
  sent once: by the main server, or 15 seconds later by the backup when the
  main server is down or its delivery fails. A main server whose delivery
  comes back within five minutes still sends its copy. A silence made on one
  reaches the other. Subscribe to the topic on both servers' ntfy.
- Give each server its ntfy's public address as `alertDelivery.ntfy.baseUrl`:
  its delivery then fails when phones can't reach that ntfy either, and the
  other server's goes out.
- A public name's alert is held back while the machine its probe names as
  `instance` is down, or while that machine's Cloudflare tunnel is.
- While the machine labelled `role = "router"` is down, the other machines'
  HostDown alerts are held back: its site is offline.
- Without a backup server, nothing alerts about the server's own outage or
  about notifications that fail to send.
- Grafana has its own login: user `admin`, password from
  `clan vars get <server> grafana-admin/password`. Provisioned dashboards are
  read-only: use Save as and promote changes to git.

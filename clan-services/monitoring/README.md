# Monitoring

Prometheus on one server scrapes every agent's node_exporter over the tailnet,
Loki keeps their journals, Grafana shows both, and alerts go to ntfy. A backup
server watches the same fleet and alerts when the main one can't.

## Roles

- `server` (NixOS): the main server runs Prometheus, Alertmanager, Loki and
  Grafana behind nginx, over the tailnet. Prometheus scrapes each agent at
  `<machine>.<agentDomain>`. Grafana is at the root of `grafana.domain`.
  Agents push their journal to `/loki/loki/api/v1/push` on `<host>`, the only
  Loki path open to them, with a generated basic auth credential. A server
  with `backup = true` runs only Prometheus and Alertmanager, with the same
  agents and rules, and notifies through its own ntfy.
- `agent` (NixOS and macOS): runs node_exporter, open to the server on the
  Tailscale interface. Other exporters go in the agent's `exporters` setting
  by job and port; modules read them back from `monitoring.exporters`.
  `*.prom` files go in `monitoring.textfileDirectory`. On NixOS, Vector ships
  the journal to Loki and buffers it on disk while the server is unreachable.
  Macs have no journal, so metrics only.
  NixOS agents with restic backups check each repository hourly: its
  snapshots (what BackupStale uses), how many are kept, the oldest, what the
  last 7 days added, and each backup's folders and exclude patterns. The
  stored size is recounted only when the snapshots change, or the next hour
  after a failed count. On machines that aren't always on, LaptopBackupStale
  counts only time the server can reach them, and BackupFailed reports a
  failed run. Agents with `probes` run blackbox_exporter, which requests each
  address when a server scrapes it, once a minute.

## Notes

- The fleet page shows each machine's newest snapshot age and links to the
  Backups page: every machine with or without a backup (one the inventory's
  `restic` instance backs up shows as set up before its first report), what
  each repository holds and for how long, and what B2 charges for it. B2's
  price, with source and date, is in `dashboards/backup-cost.nix`; the free
  10 GB come off the account total.

- Each alert is its own ntfy notification, high priority when critical. A
  resolved alert's notification is replaced by a silent one. While a machine
  is down its other alerts are held back. Tapping one opens the fleet page on
  the main server's Grafana, which must be on HTTPS once there's a backup
  server.
- Warnings labelled `send_resolved = "false"` are one-off news, such as a new
  device on the network, and get no resolved notification. If Prometheus
  stops sending one for over four minutes while it lasts, it resolves and
  fires again: a second notification.
- The servers' Alertmanagers cluster over the tailnet, so each alert is sent
  once: by the main server, or 15 seconds later by the backup when the main
  server is down or its delivery fails. A main server whose delivery recovers
  within five minutes still sends its copy. Silences sync between them.
  Subscribe to the topic on both servers' ntfy.
- Set each server's `alertDelivery.ntfy.baseUrl` to its ntfy's public
  address: its delivery then fails when phones can't reach that ntfy either,
  and the other server's goes out.
- A public name's alert is held back while the machine its probe names as
  `instance`, or that machine's Cloudflare tunnel, is down.
- While the `role = "router"` machine is down, other machines' HostDown
  alerts are held back: its site is offline.
- Without a backup server, nothing alerts on the server's own outage or on
  failed notifications.
- Grafana has its own login: user `admin`, password from
  `clan vars get <server> grafana-admin/password`. Provisioned dashboards are
  read-only: use Save as and move changes into git.

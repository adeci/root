---
name: fleet-health
description: Check the health of alex's machines (the root clan fleet) — failing services, recurring errors and warnings, slow boots or shutdowns, full disks, failing drives, heat, pending updates and reboots — by querying the fleet's Prometheus (metrics) and Loki (journals) on sequoia.
---

# Querying

Prometheus and Loki run on sequoia and listen on localhost only; query them over SSH. Both keep 30 days.

```bash
s=root@sequoia.cymric-daggertooth.ts.net
# PromQL, value now:
ssh $s 'curl -s --get localhost:9090/api/v1/query --data-urlencode "query=ALERTS{alertstate=\"firing\"}"' | jq '.data.result'
# LogQL, a number per stream (count_over_time, rate):
ssh $s 'curl -s --get localhost:3100/loki/api/v1/query --data-urlencode "query=…"' | jq '.data.result'
# LogQL, the lines themselves (start in nanoseconds):
ssh $s 'curl -s --get localhost:3100/loki/api/v1/query_range --data-urlencode "query=…" --data-urlencode "start=$(date -d "24 hours ago" +%s)000000000" --data-urlencode limit=200' | jq -r '.data.result[] | .stream.instance as $i | .values[] | "\($i) \(.[1])"'
```

Labels: `instance` is the machine name, `os` is `linux` or `macos`, `kind` is `server` or `laptop`. Metrics come from `job="node"` (node_exporter and its text files), `job="smartctl"` (Linux drives) and the router's and GPU exporters. Journal lines have `job="systemd-journal"`, `instance`, `service_name` (the unit, or the program for kernel lines), `level` (`emerg` … `err`, `warning`, `notice`, `info`, `debug`) and `transport`. Only Linux machines ship journals.

Laptops are often asleep: `up == 0` with `kind="laptop"` is normal.

# Questions

- **What is wrong right now:** `ALERTS{alertstate="firing"}`
- **Machines down:** `up{job="node"} == 0`
- **Failing services:** `node_systemd_unit_state{state="failed"} == 1`
- **Recurring errors** (LogQL), then read the lines of the top ones: `topk(20, sum by (instance, service_name) (count_over_time({job="systemd-journal", level=~"emerg|alert|crit|err"}[24h])))`
- **Recurring warnings:** the same with `level="warning"`
- **CPU busy:** `1 - sum by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) / sum by (instance) (rate(node_cpu_seconds_total[5m]))`
- **Work waiting** (share of time, Linux): `rate(node_pressure_cpu_waiting_seconds_total[5m])`, and the same for `memory` and `io`
- **Disks filling:** `disk:used:ratio` (the fullest filesystem on each physical disk)
- **Drives failing:** `smartctl_device_smart_status == 0`, `smartctl_device_media_errors > 0`, and `smartctl_device_attribute{attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable|Reported_Uncorrect", attribute_value_type="raw"} > 0`; NVMe wear is `smartctl_device_percentage_used`
- **Heat:** `node_hwmon_temp_celsius * on (instance, chip) group_left (chip_name) node_hwmon_chip_names`; a Mac's CPU is `macos_cpu_temperature_celsius`
- **CPU clocks:** `avg by (instance) (node_cpu_scaling_frequency_hertz)`
- **Slow boots:** `boot_ready_seconds`, `boot_finished_seconds` (includes catch-up jobs such as backups), `boot_phase_seconds`, and the slowest units `boot_unit_start_seconds`
- **Slow shutdowns:** `shutdown_seconds` and the slowest units `shutdown_unit_stop_seconds`, for the previous shutdown, recorded at boot
- **Out of date:** `system_nixpkgs_info` (the nixpkgs revision each machine runs), `system_nixpkgs_timestamp_seconds` (when that revision was committed; compare it across machines), `system_switch_timestamp_seconds` (when the machine last switched), `reboot_required == 1`. The repo's own commit is not recorded.
- **Mac memory pressure:** `macos_memory_pressure_level` (1 normal, 2 warning, 4 critical)

`ALERTS` names each problem; the rules behind them are in `clan-services/monitoring/rules.nix`. The fleet page is Grafana's home on https://atlas.decio.us (login needed).

# Where it is defined

`clan-services/monitoring/`: `agent.nix` (what every machine exports and ships), `server.nix` (scraping, Prometheus, Loki, Grafana), `rules.nix` (alerts and recording rules), `dashboards/`. Per-machine extras: `machines/janus/monitoring`, `machines/leviathan/monitoring.nix`.

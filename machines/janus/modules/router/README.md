# Janus Router

Janus is the L3 router for the home network.

```text
ISP modem
  -> enp5s0 (WAN, DHCP)

nexus sfp-sfpplus1
  -> eno1 (LAN trunk)
     -> vlan10 trusted 10.10.0.0/24
     -> vlan20 iot     10.20.0.0/24
     -> vlan30 guest   10.30.0.0/24
     -> vlan99 mgmt    bridged into br-mgmt

nexus ether1
  -> enp8s0 (dedicated management)
     -> br-mgmt 10.99.0.0/24

Tailscale
  -> tailscale0 admin plane + approved subnet routes
```

## Files

- `default.nix` wires the router modules and Tailscale route advertisement.
- `ports.nix` maps physical chassis labels to Linux interface names.
- `topology.nix` derives WAN/LAN/mgmt roles, VLAN interface names, and shared interface sets.
- `validation.nix` asserts that homelan inventory is coherent.
- `networkd.nix` owns all physical/VLAN/bridge interfaces.
- `firewall.nix` owns nftables forwarding/NAT policy, named counters, counter export, and rate-limited drop logging.
- `dhcp-dns.nix` owns Kea DHCP, Unbound DNS, local Kea/Unbound metrics, and Kea state.
- `probes.nix` owns Janus-local active probes plus Smokeping-style high-frequency internet quality probing.

## Trust Model

Trusted VLAN has full routed access. IoT and guest can only reach WAN.
Management has no forwarding by default; devices there can reach Janus for DHCP/DNS/API.

Tailscale is the admin plane. Janus accepts Tailnet traffic to itself and forwards approved subnet-route traffic into local VLANs. Peer authorization lives in Tailscale route approval and ACLs, not per-peer nftables rules on Janus.

## IPv6

LAN IPv6 is intentionally disabled for now. Tailscale IPv6 remains managed by Tailscale.

## Runtime State

Kea leases live in `/var/lib/kea` and are registered with `clan.core.state`.

Unbound exposes extended statistics through a Unix remote-control socket at
`/run/unbound/unbound.ctl`. `prometheus-unbound-exporter` reads it as the
`unbound` user and exposes resolver metrics on `127.0.0.1:9167` for Alloy.

`prometheus-smokeping-prober` pings `1.1.1.1` and `8.8.8.8` every second and exposes latency histograms on `127.0.0.1:9374`; Alloy scrapes it for internet latency percentiles and packet loss.

`janus-network-probe.timer` writes slower reachability/DNS/device probe metrics to
`/var/lib/alloy/textfile/janus-network-probe.prom`; Alloy's unix exporter
ships them with the rest of Janus' node metrics.

`firewall.nix` declares named nftables counters on stable policy categories
(input service accepts, invalid drops, forward zone allows, and default drops).
`janus-firewall-counters.timer` runs every 15 seconds, parses `nft -j list
ruleset`, and writes `/var/lib/alloy/textfile/janus-firewall-counters.prom`.
Prometheus labels stay bounded to `family`, `table`, `chain`, `counter`,
`action`, and `zone`; IP addresses and ports stay out of metrics.

Default input and forward drops also emit kernel nft log lines with prefixes
`janus-fw input-drop` and `janus-fw forward-drop`. Logging is rate-limited to
6/minute with a 12-packet burst per chain. Accepted traffic and established
traffic are not logged. Janus ships full journald to Loki, so these kernel logs
are available under `{instance="janus",transport="kernel"}`.

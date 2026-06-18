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
- `firewall.nix` owns nftables forwarding/NAT policy.
- `dhcp-dns.nix` owns Kea DHCP, Unbound DNS, Kea metrics, and Kea state.

## Trust Model

Trusted VLAN has full routed access. IoT and guest can only reach WAN.
Management has no forwarding by default; devices there can reach Janus for DHCP/DNS/API.

Tailscale is the admin plane. Janus accepts Tailnet traffic to itself and forwards approved subnet-route traffic into local VLANs. Peer authorization lives in Tailscale route approval and ACLs, not per-peer nftables rules on Janus.

## IPv6

LAN IPv6 is intentionally disabled for now. Tailscale IPv6 remains managed by Tailscale.

## Runtime State

Kea leases live in `/var/lib/kea` and are registered with `clan.core.state`.

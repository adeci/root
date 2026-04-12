# janus — NixOS router (Qotom Q20321G9)
# WAN (DHCP from ISP) → VLAN trunk to switches → inter-VLAN routing + NAT
#
# ── Qotom Q20321G9 Port Map ─────────────────────────────────────────
#
# 2.5G RJ45 (igc driver):
#                        Label Eth3 = enp4s0    Label Eth4 = enp5s0
#   Label Eth5 = enp8s0  Label Eth1 = enp6s0    Label Eth2 = enp7s0
#
# SFP+ right side (ixgbe driver, 10G):
#   Right-top    = eno2
#   Right-bottom = eno1
#
{ lib, ... }:
let
  # ── Port Map (label → linux interface) ─────────────────────────────
  # Profiled 2026-04-12 by plug-testing each port.
  eth1 = "enp6s0"; # 2.5G RJ45 # 2.5G RJ45 # 2.5G RJ45 # 2.5G RJ45
  eth5 = "enp8s0"; # 2.5G RJ45 # 10G SFP+ (right-top)
  sfpPlus2 = "eno1"; # 10G SFP+ (right-bottom)

  # ── Role Assignment ────────────────────────────────────────────────
  wan = eth5; # → ISP modem
  lan = sfpPlus2; # → nexus sfp-sfpplus1 (VLAN trunk)
  mgmt = eth1; # → nexus ether1 (management)

  # ── Tailscale admin IPs (stable, assigned by Tailscale) ─────────────
  tsAdmin = [
    "100.101.208.55" # praxis
    "100.64.57.12" # aegis
  ];

  # ── VLANs ──────────────────────────────────────────────────────────
  # Must match switch config in inventory/resources/routeros/
  vlans = {
    trusted = {
      id = 10;
      subnet = "10.10.0";
    };
    iot = {
      id = 20;
      subnet = "10.20.0";
    };
    guest = {
      id = 30;
      subnet = "10.30.0";
    };
    mgmt = {
      id = 99;
      subnet = "10.99.0";
    };
  };

  # ── Devices ────────────────────────────────────────────────────────
  # Static DHCP leases — single source of truth for IP assignments.
  # Firewall rules and DNS reference devices by name from this list.
  devices = {
    # Management network (VLAN 99)
    nexus = {
      mac = "08:55:31:21:A7:0D";
      ip = "10.99.0.2";
      vlan = "mgmt";
    };
    axon = {
      mac = "04:f4:1c:84:68:a6"; # sfp-sfpplus1 MAC (standalone management port)
      ip = "10.99.0.3";
      vlan = "mgmt";
    };
    zephyr = {
      mac = "04:F4:1C:E9:EF:E5";
      ip = "10.99.0.5";
      vlan = "mgmt";
    };
    nimbus = {
      mac = "04:F4:1C:EA:18:83";
      ip = "10.99.0.6";
      vlan = "mgmt";
    };

    # Trusted network (VLAN 10)
    # praxis = { mac = "xx:xx:xx:xx:xx:xx"; ip = "10.10.0.10"; vlan = "trusted"; };
  };

  # ── Helpers ────────────────────────────────────────────────────────
  vlanIf = v: "vlan${toString v.id}";
  allVlanIfs = lib.mapAttrsToList (_: vlanIf) vlans;

  # Generate dnsmasq dhcp-host lines from device list
  dhcpHosts = lib.mapAttrsToList (name: d: "${d.mac},${name},${d.ip}") devices;

  # nftables interface set literal
  ifSet = ifs: lib.concatMapStringsSep ", " (i: ''"${i}"'') ifs;
in
{
  # ── Override base.nix ──────────────────────────────────────────────
  networking.networkmanager.enable = false;

  # ── systemd-networkd ───────────────────────────────────────────────
  systemd.network.enable = true;
  networking.useNetworkd = true;
  networking.useDHCP = false;

  # VLAN sub-interfaces on the LAN trunk
  systemd.network.netdevs =
    lib.mapAttrs' (
      _: v:
      lib.nameValuePair "20-${vlanIf v}" {
        netdevConfig = {
          Name = vlanIf v;
          Kind = "vlan";
        };
        vlanConfig.Id = v.id;
      }
    ) vlans
    // {
      # Management bridge — merges dedicated mgmt RJ45 + VLAN 99 trunk
      "10-br-mgmt".netdevConfig = {
        Name = "br-mgmt";
        Kind = "bridge";
      };
    };

  systemd.network.networks = {
    # WAN — DHCP from ISP
    "10-wan" = {
      matchConfig.Name = wan;
      networkConfig.DHCP = "ipv4";
      dhcpV4Config.UseDNS = false;
    };

    # LAN — VLAN trunk to nexus
    "20-lan" = {
      matchConfig.Name = lan;
      networkConfig.VLAN = allVlanIfs;
      linkConfig.RequiredForOnline = "carrier";
    };

    # Dedicated mgmt RJ45 — bridged into br-mgmt (see netdev below)
    "20-mgmt" = {
      matchConfig.Name = mgmt;
      networkConfig.Bridge = "br-mgmt";
      linkConfig.RequiredForOnline = "no";
    };

    # VLAN 99 sub-interface — also bridged into br-mgmt
    "20-vlan99-bridge" = {
      matchConfig.Name = vlanIf vlans.mgmt;
      networkConfig.Bridge = "br-mgmt";
      linkConfig.RequiredForOnline = "no";
    };

    # Management bridge — nexus (direct RJ45) + axon/WAPs (via VLAN 99)
    # share one 10.99.0.0/24 subnet
    "30-br-mgmt" = {
      matchConfig.Name = "br-mgmt";
      address = [ "${vlans.mgmt.subnet}.1/24" ];
      linkConfig.RequiredForOnline = "no";
    };
  }
  // lib.mapAttrs' (
    _name: v:
    lib.nameValuePair "30-${vlanIf v}" {
      matchConfig.Name = vlanIf v;
      address = [ "${v.subnet}.1/24" ];
      linkConfig.RequiredForOnline = "no";
    }
  ) (lib.filterAttrs (name: _: name != "mgmt") vlans);

  # ── IP forwarding ─────────────────────────────────────────────────
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # ── Firewall (nftables) ────────────────────────────────────────────
  # Per-zone chains — each VLAN gets its own forward chain.
  # Easy to read, easy to extend. Add rules to from-* chains.
  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
    table inet filter {

      # ── Inbound to janus ───────────────────────────────────────────
      chain input {
        type filter hook input priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop
        iif lo accept
        ip protocol icmp accept

        # DHCP + DNS from all VLANs + mgmt bridge
        iifname { ${ifSet allVlanIfs}, "br-mgmt" } udp dport { 53, 67 } accept
        iifname { ${ifSet allVlanIfs}, "br-mgmt" } tcp dport 53 accept

        # Tailscale — full trust (already authenticated)
        iifname "tailscale0" accept

        # SSH from trusted + management only
        iifname { "${vlanIf vlans.trusted}", "br-mgmt" } tcp dport 22 accept
      }

      # ── Forwarding ─────────────────────────────────────────────────
      chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop

        # Tailscale — only admin machines can forward to local subnets
        iifname "tailscale0" ip saddr { ${lib.concatStringsSep ", " tsAdmin} } accept

        # Route to per-zone chains
        iifname "${vlanIf vlans.trusted}" jump from-trusted
        iifname "${vlanIf vlans.iot}"     jump from-iot
        iifname "${vlanIf vlans.guest}"   jump from-guest
        iifname "br-mgmt"                 jump from-mgmt
      }

      # ── Zone: trusted ──────────────────────────────────────────────
      # Full access — internet + all other VLANs
      chain from-trusted {
        accept
      }

      # ── Zone: iot ───────────────────────────────────────────────────
      # Internet only — no lateral movement to other VLANs
      chain from-iot {
        oifname "${wan}" accept
      }

      # ── Zone: guest ─────────────────────────────────────────────────
      # Internet only — no local network access
      chain from-guest {
        oifname "${wan}" accept
      }

      # ── Zone: mgmt ─────────────────────────────────────────────────
      # Infrastructure devices — can reach janus (for DHCP/DNS/API) but
      # not the internet or other VLANs. Switches don't need internet.
      chain from-mgmt {
      }

      chain output {
        type filter hook output priority 0; policy accept;
      }
    }

    table ip nat {
      chain postrouting {
        type nat hook postrouting priority 100;
        oifname "${wan}" masquerade
      }
    }
  '';

  # ── DHCP + DNS (dnsmasq) ───────────────────────────────────────────
  # One service for DHCP leases + DNS resolution + local domain.
  # Static leases from the devices list above.
  # Upstream DNS: Cloudflare + Quad9.
  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];

  services.dnsmasq = {
    enable = true;
    settings = {
      listen-address = [ "127.0.0.1" ] ++ map (v: "${v.subnet}.1") (lib.attrValues vlans);
      bind-dynamic = true;

      dhcp-range =
        map (v: "${vlanIf v},${v.subnet}.100,${v.subnet}.250,255.255.255.0,24h") (
          lib.attrValues (lib.filterAttrs (n: _: n != "mgmt") vlans)
        )
        ++ [ "br-mgmt,${vlans.mgmt.subnet}.100,${vlans.mgmt.subnet}.250,255.255.255.0,24h" ];

      dhcp-option =
        lib.concatMap (v: [
          "${vlanIf v},option:router,${v.subnet}.1"
          "${vlanIf v},option:dns-server,${v.subnet}.1"
        ]) (lib.attrValues (lib.filterAttrs (n: _: n != "mgmt") vlans))
        ++ [
          "br-mgmt,option:router,${vlans.mgmt.subnet}.1"
          "br-mgmt,option:dns-server,${vlans.mgmt.subnet}.1"
        ];

      dhcp-host = dhcpHosts;

      server = [
        "1.1.1.1"
        "9.9.9.9"
      ];

      # Local domain — <hostname>.lan resolves for all DHCP clients
      domain = "lan";
      local = "/lan/";
      expand-hosts = true;
      no-resolv = true;
      cache-size = 1000;
    };
  };
}

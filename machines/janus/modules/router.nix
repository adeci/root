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
{
  lib,
  pkgs,
  self,
  ...
}:
let
  # ── Port Map (label → linux interface) ─────────────────────────────
  # Profiled 2026-04-12 by plug-testing each port.
  eth4 = "enp5s0"; # 2.5G RJ45 (label Eth4)
  eth5 = "enp8s0"; # 2.5G RJ45 (label Eth5)
  sfpPlus2 = "eno1"; # 10G SFP+ (right-bottom)

  # ── Role Assignment ────────────────────────────────────────────────
  wan = eth4; # → ISP modem
  lan = sfpPlus2; # → nexus sfp-sfpplus1 (VLAN trunk)
  mgmt = eth5; # → nexus ether1 (management)

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
    tenant = {
      id = 40;
      subnet = "10.40.0";
    };
    mgmt = {
      id = 99;
      subnet = "10.99.0";
      iface = "br-mgmt"; # bridged with the dedicated mgmt RJ45
    };
  };

  # ── Devices ────────────────────────────────────────────────────────
  # Static DHCP leases — single source of truth for IP assignments.
  # Firewall rules and DNS reference devices by name from this list.
  baseDevices = {
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
    sequoia = {
      mac = "00:e0:4c:6d:c5:c9";
      ip = "10.10.0.10";
      vlan = "trusted";
    };
    leviathan = {
      mac = "e4:3d:1a:cd:96:60";
      ip = "10.10.0.20";
      vlan = "trusted";
    };
    leviathan-idrac = {
      mac = "b0:7b:25:f0:b0:c8";
      ip = "10.10.0.21";
      vlan = "trusted";
    };

    praxis = {
      mac = "4c:77:cb:ac:86:4a"; # wifi
      ip = "10.10.0.30";
      vlan = "trusted";
    };
    printer = {
      mac = "9c:93:4e:2e:6e:e1";
      ip = "10.10.0.50";
      vlan = "trusted";
    };
  };

  tenantDevices = builtins.mapAttrs (
    _name: tenant:
    let
      vlan = tenant.network or "tenant";
    in
    {
      inherit (tenant) mac;
      ip = tenant.ip or "${vlans.${vlan}.subnet}.${toString tenant.id}";
      inherit vlan;
    }
  ) self.compute.tenants;

  devices = baseDevices // tenantDevices;

  # ── Helpers ────────────────────────────────────────────────────────
  vlanIf = v: "vlan${toString v.id}";
  # The interface where DHCP/DNS for a subnet binds. Defaults to the VLAN
  # sub-interface; a vlan entry can override with `iface` (mgmt → br-mgmt).
  subnetIface = v: v.iface or (vlanIf v);
  allVlanIfs = lib.mapAttrsToList (_: vlanIf) vlans;
in
{
  # ── Override base.nix ──────────────────────────────────────────────
  networking.networkmanager.enable = false;

  # ── systemd-networkd ───────────────────────────────────────────────
  hardware.facter.detected.dhcp.enable = false;
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
  ) (lib.filterAttrs (_: v: !(v ? iface)) vlans);

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

        # Tailscale: peer-initiated wireguard from the internet (41641 is
        # Tailscale's default; without this rule only janus-initiated
        # direct paths work, via conntrack). Tunnel already authenticated.
        iifname "${wan}" udp dport 41641 accept
        iifname "tailscale0" accept

        # Route router-local traffic to per-zone input chains. This avoids
        # Linux weak-host behavior where a host on one VLAN can reach Janus'
        # IP address on another VLAN.
        iifname "${vlanIf vlans.trusted}" jump in-trusted
        iifname "${vlanIf vlans.iot}"     jump in-iot
        iifname "${vlanIf vlans.guest}"   jump in-guest
        iifname "${vlanIf vlans.tenant}"  jump in-tenant
        iifname "br-mgmt"                 jump in-mgmt
      }

      chain in-trusted {
        udp dport 67 accept
        ip daddr ${vlans.trusted.subnet}.1 udp dport 53 accept
        ip daddr ${vlans.trusted.subnet}.1 tcp dport 53 accept
        ip daddr ${vlans.trusted.subnet}.1 icmp type echo-request accept
        ip daddr ${vlans.trusted.subnet}.1 tcp dport 22 accept
      }

      chain in-iot {
        udp dport 67 accept
        ip daddr ${vlans.iot.subnet}.1 udp dport 53 accept
        ip daddr ${vlans.iot.subnet}.1 tcp dport 53 accept
        ip daddr ${vlans.iot.subnet}.1 icmp type echo-request accept
      }

      chain in-guest {
        udp dport 67 accept
        ip daddr ${vlans.guest.subnet}.1 udp dport 53 accept
        ip daddr ${vlans.guest.subnet}.1 tcp dport 53 accept
        ip daddr ${vlans.guest.subnet}.1 icmp type echo-request accept
      }

      chain in-tenant {
        udp dport 67 accept
        ip daddr ${vlans.tenant.subnet}.1 udp dport 53 accept
        ip daddr ${vlans.tenant.subnet}.1 tcp dport 53 accept
        ip daddr ${vlans.tenant.subnet}.1 icmp type echo-request accept
      }

      chain in-mgmt {
        udp dport 67 accept
        ip daddr ${vlans.mgmt.subnet}.1 udp dport 53 accept
        ip daddr ${vlans.mgmt.subnet}.1 tcp dport 53 accept
        ip daddr ${vlans.mgmt.subnet}.1 icmp type echo-request accept
        ip daddr ${vlans.mgmt.subnet}.1 tcp dport 22 accept
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
        iifname "${vlanIf vlans.tenant}"  jump from-tenant
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

      # ── Zone: tenant ────────────────────────────────────────────────
      # VM/workload network — internet only. Trusted can reach it via
      # from-trusted's full-access policy.
      chain from-tenant {
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

  # ── DHCP (Kea) + DNS (Unbound) ─────────────────────────────────────
  # Reservations and .lan records come from `devices` at deploy time;
  # dynamic clients get IPs but no .lan name.
  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = lib.mapAttrsToList (_: subnetIface) vlans;

      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/kea-leases4.csv";
      };

      # lease_cmds: control-socket lease CRUD. stat_cmds: per-subnet
      # metrics. Both consumed by prometheus-kea-exporter below.
      hooks-libraries = [
        {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_lease_cmds.so";
          parameters = { };
        }
        {
          library = "${pkgs.kea}/lib/kea/hooks/libdhcp_stat_cmds.so";
          parameters = { };
        }
      ];

      control-socket = {
        socket-type = "unix";
        socket-name = "/run/kea/kea-dhcp4.sock";
      };

      # id = v.id (not a positional index) so subnet-ids stay stable
      # across renames/additions — Kea persists subnet-id in the lease
      # CSV and keys stats by it.
      subnet4 = lib.mapAttrsToList (
        name: v:
        let
          devicesOnVlan = lib.filterAttrs (_: d: d.vlan == name) devices;
        in
        {
          inherit (v) id;
          subnet = "${v.subnet}.0/24";
          interface = subnetIface v;
          pools = [ { pool = "${v.subnet}.100 - ${v.subnet}.250"; } ];
          option-data = [
            {
              name = "routers";
              data = "${v.subnet}.1";
            }
            {
              name = "domain-name-servers";
              data = "${v.subnet}.1";
            }
            {
              name = "domain-name";
              data = "lan";
            }
          ];
          reservations = lib.mapAttrsToList (hostname: d: {
            hw-address = d.mac;
            ip-address = d.ip;
            inherit hostname;
          }) devicesOnVlan;
        }
      ) vlans;
    };
  };

  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "127.0.0.1" ] ++ map (v: "${v.subnet}.1") (lib.attrValues vlans);
        access-control = [
          "127.0.0.0/8 allow"
        ]
        ++ map (v: "${v.subnet}.0/24 allow") (lib.attrValues vlans);

        # static: unknown names → NXDOMAIN, known names with missing
        # record types → NODATA. domain-insecure skips DNSSEC for the
        # local zone (no chain of trust from root).
        local-zone = [ ''"lan." static'' ];
        local-data = lib.mapAttrsToList (name: d: ''"${name}.lan. A ${d.ip}"'') devices;
        local-data-ptr = lib.mapAttrsToList (name: d: ''"${d.ip} ${name}.lan"'') devices;
        domain-insecure = [ "lan" ];

        num-threads = 2;
        msg-cache-size = "16m";
        rrset-cache-size = "32m";
      };

      # janus disables systemd-resolved, so the @adeci/tailscale
      # dns-delegate path is a no-op here. Alloy needs .ts.net resolution
      # to push metrics to sequoia.
      forward-zone = [
        {
          name = "ts.net.";
          forward-addr = [ "100.100.100.100" ];
        }
      ];
    };
  };

  # DNS up before DHCP so the resolver Kea hands out is already serving.
  systemd.services.kea-dhcp4-server = {
    after = [ "unbound.service" ];
    wants = [ "unbound.service" ];
  };

  # Shares User="kea" + RuntimeDirectory with kea-dhcp4-server, so socket
  # access is automatic. Scraped via @adeci/monitoring extraScrapeTargets.
  services.prometheus.exporters.kea = {
    enable = true;
    listenAddress = "127.0.0.1";
    targets = [ "/run/kea/kea-dhcp4.sock" ];
  };
}

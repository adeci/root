# janus — NixOS router
# WAN (DHCP from ISP) → VLAN trunk to switches → inter-VLAN routing + NAT
{ lib, ... }:
let
  # ── Interfaces ─────────────────────────────────────────────────────
  # Temp test PC — swap these for the Qotom when ready
  wan = "enp2s0"; # built-in RJ45 → ISP modem
  lan = "enp0s20f0u2"; # USB ethernet → nexus ether24 (temp trunk) # same as lan for now — dedicated RJ45 on Qotom later
  # Qotom Q20321G9:
  # wan  = "...";  # RJ45 → ISP modem
  # lan  = "...";  # SFP+ → nexus (VLAN trunk)
  # mgmt = "...";  # RJ45 → nexus ether1 (management)

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
      mac = "04:F4:1C:84:68:A4"; # bridge VLAN 99 interface MAC (not ether1)
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
  systemd.network.netdevs = lib.mapAttrs' (
    _: v:
    lib.nameValuePair "20-${vlanIf v}" {
      netdevConfig = {
        Name = vlanIf v;
        Kind = "vlan";
      };
      vlanConfig.Id = v.id;
    }
  ) vlans;

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

    # TODO: management bridge (br-mgmt) for Qotom
    # Bridges the dedicated mgmt RJ45 with vlan99 so nexus (direct cable)
    # and axon/WAPs (via VLAN 99 trunk) share one 10.99.0.0/24 subnet.
    # Not needed on the temp PC where lan == mgmt.
  }
  // lib.mapAttrs' (
    _: v:
    lib.nameValuePair "30-${vlanIf v}" {
      matchConfig.Name = vlanIf v;
      address = [ "${v.subnet}.1/24" ];
      linkConfig.RequiredForOnline = "no";
    }
  ) vlans;

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

        # DHCP + DNS from all VLANs
        iifname { ${ifSet allVlanIfs} } udp dport { 53, 67 } accept
        iifname { ${ifSet allVlanIfs} } tcp dport 53 accept

        # Tailscale — full trust (already authenticated)
        iifname "tailscale0" accept

        # SSH from trusted + management only
        iifname { "${vlanIf vlans.trusted}", "${vlanIf vlans.mgmt}" } tcp dport 22 accept

        # WAN SSH — temp for test rig, remove for production
        iifname "${wan}" tcp dport 22 accept
      }

      # ── Forwarding ─────────────────────────────────────────────────
      chain forward {
        type filter hook forward priority 0; policy drop;

        ct state established,related accept
        ct state invalid drop

        # Route to per-zone chains
        iifname "${vlanIf vlans.trusted}" jump from-trusted
        iifname "${vlanIf vlans.iot}"     jump from-iot
        iifname "${vlanIf vlans.guest}"   jump from-guest
        iifname "${vlanIf vlans.mgmt}"    jump from-mgmt
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

      dhcp-range = map (v: "${vlanIf v},${v.subnet}.100,${v.subnet}.250,255.255.255.0,24h") (
        lib.attrValues vlans
      );

      dhcp-option = lib.concatMap (v: [
        "${vlanIf v},option:router,${v.subnet}.1"
        "${vlanIf v},option:dns-server,${v.subnet}.1"
      ]) (lib.attrValues vlans);

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

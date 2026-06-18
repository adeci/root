# janus — NixOS router (Qotom Q20321G9)
# WAN (DHCP from ISP) -> VLAN trunk to switches -> inter-VLAN routing + NAT
#
# Qotom Q20321G9 port map, profiled 2026-04-12 by plug-testing.
#
# 2.5G RJ45 (igc driver):
#                        Label Eth3 = enp4s0    Label Eth4 = enp5s0
#   Label Eth5 = enp8s0  Label Eth1 = enp6s0    Label Eth2 = enp7s0
#
# SFP+ right side (ixgbe driver, 10G):
#   Right-top    = eno2
#   Right-bottom = eno1
{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  ports = {
    eth1 = "enp6s0";
    eth2 = "enp7s0";
    eth3 = "enp4s0";
    eth4 = "enp5s0";
    eth5 = "enp8s0";
    sfpPlus1 = "eno2";
    sfpPlus2 = "eno1";
    sfpPlus3 = "eno3";
    sfpPlus4 = "eno4";
  };

  wan = ports.eth4; # -> ISP modem
  lan = ports.sfpPlus2; # -> nexus sfp-sfpplus1 (VLAN trunk)
  mgmt = ports.eth5; # -> nexus ether1 (management)

  inherit (self.resources) homelan;
  inherit (homelan) vlans;

  devices = homelan.hosts;
  dnsRecords = homelan.dns.records;
  dnsDevices = lib.filterAttrs (_: host: host.publishDns or true) devices;

  vlanIf = vlan: "vlan${toString vlan.id}";
  subnetIface = vlan: vlan.iface or (vlanIf vlan);

  physicalIfs = lib.attrValues ports;
  spareIfs = lib.subtractLists [
    wan
    lan
    mgmt
  ] physicalIfs;

  trunkVlanIfs = lib.mapAttrsToList (_: vlanIf) vlans;
  routedVlans = lib.filterAttrs (name: _: name != "mgmt") vlans;
  routedVlanIfs = lib.mapAttrsToList (_: vlanIf) routedVlans;
  serviceIfs = routedVlanIfs ++ [ "br-mgmt" ];
  localForwardIfs = serviceIfs;

  noIpv6 = {
    LinkLocalAddressing = "no";
    IPv6AcceptRA = false;
  };

  tailscaleRouteFlag = "--advertise-routes=${
    lib.concatMapStringsSep "," (vlan: vlan.cidr) (lib.attrValues vlans)
  }";

  ifSet = ifs: lib.concatMapStringsSep ", " (iface: ''"${iface}"'') ifs;

  countMatching = pred: values: builtins.length (builtins.filter pred values);
  duplicates =
    values:
    lib.filter (value: countMatching (candidate: candidate == value) values > 1) (lib.unique values);
  lower = value: lib.toLower value;

  knownVlanHosts = lib.filterAttrs (_: host: host ? vlan && lib.hasAttr host.vlan vlans) devices;

  allAliases = lib.concatMap (host: host.aliases or [ ]) (lib.attrValues dnsDevices);
  localAliases = lib.concatMapAttrs (
    _hostName: host:
    builtins.listToAttrs (
      map (alias: {
        name = alias;
        value = host.ip;
      }) (host.aliases or [ ])
    )
  ) dnsDevices;

  hostIps = lib.mapAttrsToList (_: host: host.ip or null) devices;
  hostMacs = lib.mapAttrsToList (_: host: lower host.mac) (
    lib.filterAttrs (_: host: host ? mac) devices
  );
  hostClientIds = lib.mapAttrsToList (_: host: lower host.clientId) (
    lib.filterAttrs (_: host: host ? clientId) devices
  );

  hostsMissingIp = lib.attrNames (lib.filterAttrs (_: host: !(host ? ip)) devices);
  hostsMissingReservationId = lib.attrNames (
    lib.filterAttrs (_: host: !(host ? mac || host ? clientId)) devices
  );
  hostsWithUnknownVlans = lib.attrNames (
    lib.filterAttrs (_: host: !(host ? vlan) || !(lib.hasAttr host.vlan vlans)) devices
  );
  hostsOutsideVlan = lib.attrNames (
    lib.filterAttrs (
      _: host: !(host ? ip) || !(lib.hasPrefix "${vlans.${host.vlan}.prefix}." host.ip)
    ) knownVlanHosts
  );

  ipLastOctet =
    ip:
    let
      match = builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.([0-9]+)" ip;
    in
    if match == null then null else lib.toInt (builtins.head match);

  ipInDhcpPool =
    vlan: ip:
    let
      octet = ipLastOctet ip;
      start = ipLastOctet vlan.dhcpPool.start;
      end = ipLastOctet vlan.dhcpPool.end;
    in
    octet != null && start != null && end != null && octet >= start && octet <= end;

  hostsInsideDhcpPools = lib.attrNames (
    lib.filterAttrs (
      _: host:
      host ? ip && host ? vlan && lib.hasAttr host.vlan vlans && ipInDhcpPool vlans.${host.vlan} host.ip
    ) devices
  );

  vlanIds = map (vlan: vlan.id) (lib.attrValues vlans);
  vlansWithBadGateway = lib.attrNames (
    lib.filterAttrs (_: vlan: !(lib.hasPrefix "${vlan.prefix}." vlan.gateway)) vlans
  );
  vlansWithBadDhcpPool = lib.attrNames (
    lib.filterAttrs (
      _: vlan:
      !(lib.hasPrefix "${vlan.prefix}." vlan.dhcpPool.start)
      || !(lib.hasPrefix "${vlan.prefix}." vlan.dhcpPool.end)
    ) vlans
  );

  aliasHostConflicts = lib.intersectLists allAliases (lib.attrNames devices);
  duplicateAliases = duplicates allAliases;
  duplicateIps = duplicates (lib.filter (ip: ip != null) hostIps);
  duplicateMacs = duplicates hostMacs;
  duplicateClientIds = duplicates hostClientIds;

  ifaceForTarget =
    target:
    if target == "wan" then
      wan
    else if target == "tailscale" then
      "tailscale0"
    else
      forwardZones.${target}.iface;

  forwardZones = {
    trusted = {
      iface = vlanIf vlans.trusted;
      description = "trusted clients; full routed access";
      allowAny = true;
    };
    iot = {
      iface = vlanIf vlans.iot;
      description = "IoT clients; internet only";
      allow = [ "wan" ];
    };
    guest = {
      iface = vlanIf vlans.guest;
      description = "guest clients; internet only";
      allow = [ "wan" ];
    };
    mgmt = {
      iface = "br-mgmt";
      description = "infrastructure management; no forwarding by default";
      allow = [ ];
    };
  };

  mkForwardRules =
    zone:
    if zone.allowAny or false then
      [ "accept" ]
    else
      map (target: ''oifname "${ifaceForTarget target}" accept'') zone.allow;

  indentLines = prefix: lines: lib.concatMapStringsSep "\n" (line: "${prefix}${line}") lines;

  mkZoneChain =
    name: zone:
    let
      rules = mkForwardRules zone;
    in
    lib.concatStringsSep "\n" (
      [
        "  # ${zone.description}"
        "  chain from-${name} {"
      ]
      ++ map (rule: "    ${rule}") rules
      ++ [ "  }" ]
    );

  zoneJumps = indentLines "    " (
    lib.mapAttrsToList (name: zone: ''iifname "${zone.iface}" jump from-${name}'') forwardZones
  );
  zoneChains = lib.concatStringsSep "\n" (lib.mapAttrsToList mkZoneChain forwardZones);
in
{
  assertions = [
    {
      assertion = lib.length vlanIds == lib.length (lib.unique vlanIds);
      message = "homelan VLAN IDs must be unique";
    }
    {
      assertion = vlansWithBadGateway == [ ];
      message = "homelan VLAN gateways must live inside their VLAN prefix: ${lib.concatStringsSep ", " vlansWithBadGateway}";
    }
    {
      assertion = vlansWithBadDhcpPool == [ ];
      message = "homelan DHCP pools must live inside their VLAN prefix: ${lib.concatStringsSep ", " vlansWithBadDhcpPool}";
    }
    {
      assertion = hostsMissingIp == [ ];
      message = "homelan hosts must declare ip: ${lib.concatStringsSep ", " hostsMissingIp}";
    }
    {
      assertion = hostsMissingReservationId == [ ];
      message = "homelan hosts must declare mac or clientId: ${lib.concatStringsSep ", " hostsMissingReservationId}";
    }
    {
      assertion = hostsWithUnknownVlans == [ ];
      message = "homelan hosts reference unknown VLANs: ${lib.concatStringsSep ", " hostsWithUnknownVlans}";
    }
    {
      assertion = hostsOutsideVlan == [ ];
      message = "homelan host IPs must match their VLAN prefix: ${lib.concatStringsSep ", " hostsOutsideVlan}";
    }
    {
      assertion = hostsInsideDhcpPools == [ ];
      message = "homelan static host reservations must stay outside DHCP pools: ${lib.concatStringsSep ", " hostsInsideDhcpPools}";
    }
    {
      assertion = duplicateIps == [ ];
      message = "homelan host IPs must be unique: ${lib.concatStringsSep ", " duplicateIps}";
    }
    {
      assertion = duplicateMacs == [ ];
      message = "homelan host MACs must be unique: ${lib.concatStringsSep ", " duplicateMacs}";
    }
    {
      assertion = duplicateClientIds == [ ];
      message = "homelan DHCP client IDs must be unique: ${lib.concatStringsSep ", " duplicateClientIds}";
    }
    {
      assertion = duplicateAliases == [ ];
      message = "homelan aliases must be unique: ${lib.concatStringsSep ", " duplicateAliases}";
    }
    {
      assertion = aliasHostConflicts == [ ];
      message = "homelan aliases conflict with host names: ${lib.concatStringsSep ", " aliasHostConflicts}";
    }
  ];

  networking.networkmanager.enable = false;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  hardware.facter.detected.dhcp.enable = false;

  services.tailscale = {
    extraUpFlags = [ tailscaleRouteFlag ];
    extraSetFlags = [
      "--accept-routes=false"
      tailscaleRouteFlag
    ];
    useRoutingFeatures = "server";
  };

  systemd.network.enable = true;
  systemd.network.netdevs =
    lib.mapAttrs' (
      _: vlan:
      lib.nameValuePair "20-${vlanIf vlan}" {
        netdevConfig = {
          Name = vlanIf vlan;
          Kind = "vlan";
        };
        vlanConfig.Id = vlan.id;
      }
    ) vlans
    // {
      "10-br-mgmt".netdevConfig = {
        Name = "br-mgmt";
        Kind = "bridge";
      };
    };

  systemd.network.networks = {
    "10-wan" = {
      matchConfig.Name = wan;
      networkConfig = noIpv6 // {
        DHCP = "ipv4";
      };
      dhcpV4Config.UseDNS = false;
    };

    "20-lan" = {
      matchConfig.Name = lan;
      linkConfig.RequiredForOnline = "carrier";
      networkConfig = noIpv6 // {
        VLAN = trunkVlanIfs;
      };
    };

    "20-mgmt" = {
      matchConfig.Name = mgmt;
      linkConfig.RequiredForOnline = "no";
      networkConfig = noIpv6 // {
        Bridge = "br-mgmt";
      };
    };

    "20-vlan99-bridge" = {
      matchConfig.Name = vlanIf vlans.mgmt;
      linkConfig.RequiredForOnline = "no";
      networkConfig = noIpv6 // {
        Bridge = "br-mgmt";
      };
    };

    "30-br-mgmt" = {
      matchConfig.Name = "br-mgmt";
      address = [ "${vlans.mgmt.gateway}/24" ];
      linkConfig.RequiredForOnline = "no";
      networkConfig = noIpv6;
    };
  }
  // lib.mapAttrs' (
    _name: vlan:
    lib.nameValuePair "30-${vlanIf vlan}" {
      matchConfig.Name = vlanIf vlan;
      address = [ "${vlan.gateway}/24" ];
      linkConfig.RequiredForOnline = "no";
      networkConfig = noIpv6;
    }
  ) routedVlans
  // lib.listToAttrs (
    map (iface: {
      name = "90-spare-${iface}";
      value = {
        matchConfig.Name = iface;
        linkConfig.RequiredForOnline = "no";
        networkConfig = noIpv6;
      };
    }) spareIfs
  );

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
  };

  networking.firewall.enable = false;
  networking.nftables.enable = true;
  networking.nftables.ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            ct state established,related accept
            ct state invalid drop
            iif lo accept
            ip protocol icmp accept

            # DHCP + DNS for local subnets.
            iifname { ${ifSet serviceIfs} } udp dport { 53, 67 } accept
            iifname { ${ifSet serviceIfs} } tcp dport 53 accept

            # Tailscale direct path from WAN. Tunnel traffic is authenticated by
            # WireGuard; Tailscale ACLs remain the peer policy boundary.
            iifname "${wan}" udp dport 41641 accept

            # Tailnet is the admin plane for Janus itself.
            iifname "tailscale0" accept

            # SSH from trusted + management only.
            iifname { "${vlanIf vlans.trusted}", "br-mgmt" } tcp dport 22 accept
          }

          chain forward {
            type filter hook forward priority 0; policy drop;

            ct state established,related accept
            ct state invalid drop

            # Tailscale subnet routes. Route approval and Tailscale ACLs decide
            # which peers can use these local networks.
            iifname "tailscale0" oifname { ${ifSet localForwardIfs} } accept

    ${zoneJumps}
          }

    ${zoneChains}

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

      subnet4 = lib.mapAttrsToList (
        name: vlan:
        let
          devicesOnVlan = lib.filterAttrs (_: device: device.vlan == name) devices;
        in
        {
          inherit (vlan) id;
          subnet = vlan.cidr;
          interface = subnetIface vlan;
          pools = [ { pool = "${vlan.dhcpPool.start} - ${vlan.dhcpPool.end}"; } ];
          option-data = [
            {
              name = "routers";
              data = vlan.gateway;
            }
            {
              name = "domain-name-servers";
              data = vlan.gateway;
            }
            {
              name = "domain-name";
              data = homelan.domain;
            }
          ];
          reservations = lib.mapAttrsToList (
            hostname: device:
            {
              ip-address = device.ip;
              inherit hostname;
            }
            // (if device ? clientId then { client-id = device.clientId; } else { hw-address = device.mac; })
          ) devicesOnVlan;
        }
      ) vlans;
    };
  };

  services.unbound = {
    enable = true;
    settings = {
      server = {
        interface = [ "127.0.0.1" ] ++ map (vlan: vlan.gateway) (lib.attrValues vlans);
        access-control = [ "127.0.0.0/8 allow" ] ++ map (vlan: "${vlan.cidr} allow") (lib.attrValues vlans);

        local-zone = [
          ''"${homelan.domain}." static''
        ]
        ++ lib.mapAttrsToList (name: _: ''"${name}." static'') dnsRecords;
        local-data =
          lib.mapAttrsToList (name: device: ''"${name}.${homelan.domain}. A ${device.ip}"'') dnsDevices
          ++ lib.mapAttrsToList (name: ip: ''"${name}.${homelan.domain}. A ${ip}"'') localAliases
          ++ lib.mapAttrsToList (name: ip: ''"${name}. A ${ip}"'') dnsRecords;
        local-data-ptr = lib.mapAttrsToList (
          name: device: ''"${device.ip} ${name}.${homelan.domain}"''
        ) dnsDevices;
        domain-insecure = [ homelan.domain ] ++ lib.attrNames dnsRecords;

        do-ip6 = false;
        prefer-ip6 = false;
        num-threads = 2;
        msg-cache-size = "16m";
        rrset-cache-size = "32m";
      };

      # Janus disables systemd-resolved, so @adeci/tailscale's dns-delegate
      # path is intentionally unused here. Unbound forwards Tailnet names to
      # MagicDNS directly for local services such as Alloy.
      forward-zone = [
        {
          name = "ts.net.";
          forward-addr = [ "100.100.100.100" ];
        }
      ];
    };
  };

  systemd.services.kea-dhcp4-server = {
    after = [ "unbound.service" ];
    wants = [ "unbound.service" ];
  };

  services.prometheus.exporters.kea = {
    enable = true;
    listenAddress = "127.0.0.1";
    targets = [ "/run/kea/kea-dhcp4.sock" ];
  };

  clan.core.state.kea-dhcp = {
    folders = [ "/var/lib/kea" ];
    preRestoreScript = ''
      ${config.systemd.package}/bin/systemctl stop kea-dhcp4-server.service || true
    '';
    postRestoreScript = ''
      ${config.systemd.package}/bin/systemctl start kea-dhcp4-server.service
    '';
  };
}

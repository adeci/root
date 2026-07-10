{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  topology = import ./topology.nix { inherit lib self; };

  devices = topology.homelan.hosts;
  dnsRecords = topology.homelan.dns.records;
  dnsDevices = lib.filterAttrs (_: host: host.publishDns or true) devices;

  localAliases = lib.concatMapAttrs (
    _hostName: host:
    builtins.listToAttrs (
      map (alias: {
        name = alias;
        value = host.ip;
      }) (host.aliases or [ ])
    )
  ) dnsDevices;

  routerLanWaitArgs = lib.escapeShellArgs (
    map (interface: "--interface=${interface}:routable") topology.serviceInterfaces
    ++ [ "--timeout=30" ]
  );
in
{
  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = lib.mapAttrsToList (
        _: vlan: topology.subnetInterface vlan
      ) topology.vlans;

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
          interface = topology.subnetInterface vlan;
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
              data = topology.homelan.domain;
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
      ) topology.vlans;
    };
  };

  services.unbound = {
    enable = true;
    localControlSocketPath = "/run/unbound/unbound.ctl";
    settings = {
      server = {
        interface = [ "127.0.0.1" ] ++ map (vlan: vlan.gateway) (lib.attrValues topology.vlans);
        access-control = [
          "127.0.0.0/8 allow"
        ]
        ++ map (vlan: "${vlan.cidr} allow") (lib.attrValues topology.vlans);

        local-zone = [
          ''"${topology.homelan.domain}." static''
        ]
        ++ lib.mapAttrsToList (name: _: ''"${name}." static'') dnsRecords;
        local-data =
          lib.mapAttrsToList (
            name: device: ''"${name}.${topology.homelan.domain}. A ${device.ip}"''
          ) dnsDevices
          ++ lib.mapAttrsToList (name: ip: ''"${name}.${topology.homelan.domain}. A ${ip}"'') localAliases
          ++ lib.mapAttrsToList (name: ip: ''"${name}. A ${ip}"'') dnsRecords;
        local-data-ptr = lib.mapAttrsToList (
          name: device: ''"${device.ip} ${name}.${topology.homelan.domain}"''
        ) dnsDevices;
        domain-insecure = [ topology.homelan.domain ] ++ lib.attrNames dnsRecords;

        extended-statistics = true;
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

  systemd.services.router-lan-online = {
    description = "Wait for Janus LAN interfaces";
    after = [ "systemd-networkd.service" ];
    requires = [ "systemd-networkd.service" ];
    before = [ "kea-dhcp4-server.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${config.systemd.package}/lib/systemd/systemd-networkd-wait-online ${routerLanWaitArgs}
    '';
  };

  systemd.services.kea-dhcp4-server = {
    after = [
      "router-lan-online.service"
      "unbound.service"
    ];
    wants = [
      "router-lan-online.service"
      "unbound.service"
    ];
    serviceConfig.RestartSec = "5s";
  };

  systemd.services.prometheus-kea-exporter = {
    after = [ "kea-dhcp4-server.service" ];
    requires = [ "kea-dhcp4-server.service" ];
    serviceConfig = {
      RestartSec = "5s";
      RuntimeDirectoryMode = "0750";
    };
  };

  services.prometheus.exporters.kea = {
    enable = true;
    listenAddress = "127.0.0.1";
    targets = [ "/run/kea/kea-dhcp4.sock" ];
  };

  services.prometheus.exporters.unbound = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9167;
    user = "unbound";
    group = "unbound";
    unbound = {
      host = "unix://${config.services.unbound.localControlSocketPath}";
      ca = null;
      certificate = null;
      key = null;
    };
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

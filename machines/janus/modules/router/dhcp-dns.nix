{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (self.inventory) lan machines;
  inherit (lan) vlans hosts;
  # The address each full name in lan.dns resolves to: a LAN host's, or a machine's tailnet address.
  dnsAddresses = lib.mapAttrs (
    _: record: if record ? lan then hosts.${record.lan}.ip else machines.${record.tailnet}.tailnet
  ) lan.dns;
  publishedHosts = lib.filterAttrs (_: host: host.publishDns) hosts;
  gatewayInterfaces = lib.mapAttrsToList (_: vlan: vlan.interface) vlans;
  waitArguments = map (interface: "--interface=${interface}:routable") gatewayInterfaces ++ [
    "--timeout=30"
  ];
in
{
  services.resolved.enable = false;
  networking.nameservers = [ "127.0.0.1" ];

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = gatewayInterfaces;

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
          hostsOnVlan = lib.filterAttrs (_: host: host.vlan == name) hosts;
        in
        {
          inherit (vlan) id interface;
          subnet = vlan.cidr;
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
              data = lan.domain;
            }
          ];
          reservations = lib.mapAttrsToList (
            hostname: host:
            {
              ip-address = host.ip;
              inherit hostname;
            }
            // (if host.clientId != null then { client-id = host.clientId; } else { hw-address = host.mac; })
          ) hostsOnVlan;
        }
      ) vlans;
    };
  };

  services.unbound = {
    enable = true;
    localControlSocketPath = "/run/unbound/unbound.ctl";
    settings = {
      server = {
        interface = [ "127.0.0.1" ] ++ map (vlan: vlan.gateway) (lib.attrValues vlans);
        access-control = [
          "127.0.0.0/8 allow"
          # Tailscale split DNS sends the private names here
          "${self.inventory.tailnet.cidr} allow"
        ]
        ++ map (vlan: "${vlan.cidr} allow") (lib.attrValues vlans);

        local-zone = [
          ''"${lan.domain}." static''
        ]
        ++ lib.mapAttrsToList (name: _: ''"${name}." transparent'') dnsAddresses;
        local-data =
          lib.mapAttrsToList (name: host: ''"${name}.${lan.domain}. A ${host.ip}"'') publishedHosts
          ++ lib.mapAttrsToList (name: ip: ''"${name}. A ${ip}"'') dnsAddresses;
        local-data-ptr = lib.mapAttrsToList (
          name: host: ''"${host.ip} ${name}.${lan.domain}"''
        ) publishedHosts;
        domain-insecure = [ lan.domain ] ++ lib.attrNames dnsAddresses;

        extended-statistics = true;
        do-ip6 = false;
        prefer-ip6 = false;
        num-threads = 2;
        msg-cache-size = "16m";
        rrset-cache-size = "32m";
      };

      # With systemd-resolved off, Unbound forwards tailnet names to MagicDNS for local services.
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
      ExecStart = "${config.systemd.package}/lib/systemd/systemd-networkd-wait-online ${toString waitArguments}";
    };
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

  monitoring.scrapeTargets =
    let
      inherit (config.services.prometheus.exporters) kea unbound;
    in
    {
      kea-dhcp4 = "${kea.listenAddress}:${toString kea.port}";
      unbound = "${unbound.listenAddress}:${toString unbound.port}";
    };

  clan.core.state.kea-dhcp = {
    folders = [ "/var/lib/kea" ];
    preRestoreScript = ''
      ${lib.getExe' config.systemd.package "systemctl"} stop kea-dhcp4-server.service || true
    '';
    postRestoreScript = ''
      ${lib.getExe' config.systemd.package "systemctl"} start kea-dhcp4-server.service
    '';
  };
}

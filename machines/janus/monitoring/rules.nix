# Alerts about the router's own services, its internet link and the RouterOS switches and access points.
{ network }:
let
  router = ''instance="${network.instance}"'';
  mikrotik = ''${router}, job="mikrotik"'';

  internetDown = ''
    max by (instance) (janus_network_probe_up{${router}, group="internet"}) == 0
    or min by (instance) (janus_network_probe_up{${router}, group="wan"}) == 0
  '';

  internetLoss = ''
    1 - sum by (instance) (rate(smokeping_response_duration_seconds_count{${router}, group="internet"}[10m]))
      / sum by (instance) (rate(smokeping_requests_total{${router}, group="internet"}[10m]))
  '';

  unitInactive = unit: ''node_systemd_unit_state{${router}, name="${unit}", state="active"} == 0'';

  cableErrors =
    direction:
    network.onPorts network.cabledPorts (
      ports: "rate(mikrotik_interface_${direction}_error{${mikrotik}, ${ports}}[15m])"
    );

  # mikrotik_monitor_rate is in Mb/s; SFP+ ports should link at 10 Gb/s, copper ports at 1 Gb/s.
  slowFibreCables = network.onPorts network.cablePorts (
    ports: ''mikrotik_monitor_rate{${mikrotik}, ${ports}, interface=~"sfp-sfpplus.+"} < 10000''
  );
  slowCopperCables = network.onPorts network.cablePorts (
    ports: ''mikrotik_monitor_rate{${mikrotik}, ${ports}, interface=~"ether.+"} < 1000''
  );
in
[
  {
    alert = "InternetDown";
    expr = internetDown;
    for = "5m";
    labels.severity = "warning";
    annotations = {
      summary = "The internet connection is down";
      description = "The ISP gateway or every internet probe has stopped answering; check the modem and the WAN link.";
    };
  }
  {
    alert = "InternetPacketLoss";
    expr = ''
      (${internetLoss}) > 0.1
      unless on (instance) (${internetDown})
    '';
    for = "15m";
    labels.severity = "warning";
    annotations = {
      summary = "The internet connection is losing packets";
      description = "{{ $value | humanizePercentage }} of pings to internet hosts get no answer.";
    };
  }
  {
    alert = "DnsFailing";
    expr = ''
      (
        max by (instance) (janus_dns_probe_up{${router}}) == 0
        unless on (instance) (${internetDown})
      )
      or max by (instance) (${unitInactive "unbound.service"})
    '';
    for = "5m";
    labels.severity = "critical";
    annotations = {
      summary = "The LAN's DNS resolver is failing";
      description = "Unbound is down or can't resolve names while the internet is up; see `systemctl status unbound` on {{ $labels.instance }}.";
    };
  }
  {
    alert = "DhcpDown";
    expr = unitInactive "kea-dhcp4-server.service";
    for = "3m";
    labels.severity = "critical";
    annotations = {
      summary = "The LAN's DHCP server is down";
      description = "New devices can't join the network; see `systemctl status kea-dhcp4-server` on {{ $labels.instance }}.";
    };
  }
  {
    alert = "DhcpPoolExhausted";
    expr = ''
      kea_dhcp4_addresses_assigned_total{${router}, pool!=""}
        / kea_dhcp4_addresses_total{${router}, pool!=""}
        > 0.9
    '';
    for = "30m";
    labels.severity = "warning";
    annotations = {
      summary = "The DHCP pool for {{ $labels.subnet }} is nearly used up";
      description = "{{ $value | humanizePercentage }} of {{ $labels.pool }} is leased.";
    };
  }
  {
    alert = "FirewallDown";
    expr = unitInactive "nftables.service";
    for = "3m";
    labels.severity = "critical";
    annotations = {
      summary = "The router's firewall is not loaded";
      description = "nftables.service is inactive on {{ $labels.instance }}; see its journal.";
    };
  }
  {
    alert = "RouterOSDeviceDown";
    expr = ''janus_network_probe_up{${router}, group="routeros"} == 0'';
    for = "5m";
    labels.severity = "warning";
    annotations = {
      summary = "{{ $labels.target }} is unreachable";
      description = "The router can't ping {{ $labels.target }} at {{ $labels.address }}; check its power and uplink.";
    };
  }
  {
    alert = "RouterOSLinkErrors";
    expr = ''
      sum by (name, interface) (
        ${cableErrors "rx"}
      )
      + sum by (name, interface) (
        ${cableErrors "tx"}
      )
      > 0.01
    '';
    for = "15m";
    labels.severity = "warning";
    annotations = {
      summary = "{{ $labels.name }} {{ $labels.interface }} has link errors";
      description = "{{ $value | humanize }} errors/s on a cabled port; check the cable, transceiver and the port at its other end.";
    };
  }
  {
    alert = "RouterOSLinkSlow";
    expr = ''
      (
        ${slowFibreCables}
        or ${slowCopperCables}
      )
      and on (name, interface) mikrotik_monitor_status{${mikrotik}} == 1
    '';
    for = "1h";
    labels.severity = "warning";
    annotations = {
      summary = "{{ $labels.name }} {{ $labels.interface }} links at only {{ $value }} Mb/s";
      description = "The cable on this port negotiated below the port's speed; reseat or replace it.";
    };
  }
  {
    alert = "RouterOSTooHot";
    expr = "max by (name) (janus_routeros_temperature_celsius{${router}}) > 85";
    for = "15m";
    labels.severity = "warning";
    annotations = {
      summary = "{{ $labels.name }} is running hot";
      description = "Its hottest sensor reads {{ $value }}°C; check its airflow and PoE load.";
    };
  }
  {
    alert = "RouterOSMetricsFailing";
    expr = ''
      (
        min by (name) (label_replace(mikrotik_scrape_collector_success{${router}}, "name", "$1", "device", "(.+)")) == 0
        or min by (name) (janus_routeros_health_scrape_success{${router}}) == 0
      )
      unless on (name) label_replace(janus_network_probe_up{${router}, group="routeros"} == 0, "name", "$1", "target", "(.+)")
    '';
    for = "30m";
    labels.severity = "warning";
    annotations = {
      summary = "Metrics from {{ $labels.name }} are failing";
      description = "{{ $labels.name }} answers pings but not its API; check the prometheus API user and the API service on it.";
    };
  }
]

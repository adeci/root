{ ui, queries, ... }:
let
  inherit (queries) router;
  unbound = ''${router}, job="unbound"'';
  services = builtins.concatStringsSep "|" [
    "kea-dhcp4-server.service"
    "unbound.service"
    "nftables.service"
    "tailscaled.service"
    "chronyd.service"
  ];
  lookupTime =
    quantile:
    "histogram_quantile(${quantile}, sum by (le) (rate(unbound_response_time_seconds_bucket{${unbound}}[$__rate_interval])))";
  tailnet =
    direction:
    ''8 * rate(node_network_${direction}_bytes_total{${router}, device="tailscale0"}[$__rate_interval])'';
in
ui.row {
  title = "Router";
  panels = [
    (ui.stateTimeline {
      title = "Services";
      w = 24;
      h = 5;
      targets = [
        (ui.target ''max by (name) (node_systemd_unit_state{${router}, state="active", name=~"${services}"})'' "{{name}}")
      ];
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
    (ui.timeseries {
      title = "Clients by network";
      w = 12;
      h = 8;
      targets = [
        (ui.target "max by (network) (${queries.perVlan (vlan: ''kea_dhcp4_addresses_assigned_total{${router}, pool="", subnet_id="${toString vlan.id}"}'')})" "{{network}}")
      ];
    })
    (ui.timeseries {
      title = "Name lookups";
      w = 12;
      h = 8;
      unit = "reqps";
      targets = [
        (ui.target "sum by (rcode) (rate(unbound_answer_rcodes_total{${unbound}}[$__rate_interval])) > 0" "{{rcode}}")
      ];
    })
    (ui.timeseries {
      title = "Lookup time";
      w = 8;
      h = 8;
      unit = "s";
      targets = [
        (ui.target (lookupTime "0.5") "median")
        (ui.target (lookupTime "0.95") "95th percentile")
      ];
    })
    (ui.timeseries {
      title = "Clock error";
      w = 8;
      h = 8;
      unit = "s";
      targets = [ (ui.target "node_timex_maxerror_seconds{${router}}" "maximum error") ];
    })
    (ui.timeseries {
      title = "Tailnet";
      w = 8;
      h = 8;
      unit = "bps";
      targets = [
        (ui.target (tailnet "receive") "in")
        (ui.target (tailnet "transmit") "out")
      ];
    })
  ];
}

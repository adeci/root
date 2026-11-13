{ ui, queries, ... }:
let
  inherit (queries) router;

  packets =
    counters:
    ''sum(rate(janus_firewall_counter_packets_total{${router},family="inet",table="filter",${counters}}[$__rate_interval])) or on() vector(0)'';
in
ui.row {
  title = "Firewall";
  panels = [
    (ui.timeseries {
      title = "Firewall Drops";
      w = 8;
      h = 8;
      unit = "pps";
      threshold = ui.thresholds.goodWhenZero;
      targets = [
        (ui.target (packets ''counter="input_drop_default"'') "input default deny")
        (ui.target (packets ''counter="forward_drop_default"'') "forward default deny")
        (ui.target (packets ''counter="input_drop_invalid"'') "input invalid")
        (ui.target (packets ''counter="forward_drop_invalid"'') "forward invalid")
      ];
      overrides = [
        (ui.colorOverride "input default deny" "red")
        (ui.colorOverride "forward default deny" "orange")
        (ui.colorOverride "input invalid" "purple")
        (ui.colorOverride "forward invalid" "blue")
      ];
    })
    (ui.timeseries {
      title = "Firewall Decisions";
      w = 16;
      h = 8;
      unit = "pps";
      threshold = ui.thresholds.neutral;
      targets = [
        (ui.target (packets ''counter="forward_accept_trusted"'') "trusted forward")
        (ui.target (packets ''counter=~"forward_accept_.+_to_wan"'') "internet-only wan")
        (ui.target (packets ''counter="input_accept_dhcp_dns"'') "local dns/dhcp")
        (ui.target (packets ''counter=~"input_accept_ssh_admin|input_accept_tailnet_admin|input_accept_tailscale_direct_udp|forward_accept_tailscale_to_local"'') "admin/tailscale")
        (ui.target (packets ''action="drop"'') "dropped")
      ];
      overrides = [
        (ui.colorOverride "trusted forward" "green")
        (ui.colorOverride "internet-only wan" "yellow")
        (ui.colorOverride "local dns/dhcp" "blue")
        (ui.colorOverride "admin/tailscale" "purple")
        (ui.colorOverride "dropped" "red")
      ];
    })

    (ui.logs {
      title = "Recent Firewall Drop Logs";
      w = 24;
      h = 10;
      expr = ''{${router},transport="kernel"} |= "janus-fw "'';
    })
  ];
}

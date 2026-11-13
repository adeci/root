{ ui, queries, ... }:
let
  inherit (queries) internetLatency;

  lossPercent = expr: "100 * (${expr})";
in
ui.row {
  title = "Gateway / WAN";
  panels = [
    (ui.timeseries {
      title = "Gateway + Internet Latency";
      w = 8;
      h = 8;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target ''1000 * janus_network_probe_latency_seconds{group=~"wan|internet"}'' "{{target}}")
      ];
      overrides = [
        (ui.colorOverride "wan_gateway" "green")
        (ui.colorOverride "cloudflare_dns" "blue")
        (ui.colorOverride "google_dns" "orange")
      ];
    })
    (ui.timeseries {
      title = "Internet Latency Spread";
      w = 8;
      h = 8;
      unit = "ms";
      threshold = ui.thresholds.latencyMs;
      targets = [
        (ui.target "(${internetLatency "0.95"}) - (${internetLatency "0.50"})" "p95 - p50")
        (ui.target "(${internetLatency "0.99"}) - (${internetLatency "0.50"})" "p99 - p50")
      ];
      overrides = [
        (ui.colorOverride "p95 - p50" "orange")
        (ui.colorOverride "p99 - p50" "red")
      ];
    })
    (ui.timeseries {
      title = "Gateway + Internet Packet Loss";
      w = 8;
      h = 8;
      unit = "percent";
      threshold = ui.thresholds.packetLossPercent;
      targets = [
        (ui.target (lossPercent ''janus_network_probe_packet_loss_ratio{target="wan_gateway"}'') "wan gateway")
        (ui.target queries.internetLoss "internet")
      ];
      overrides = [
        (ui.colorOverride "wan gateway" "green")
        (ui.colorOverride "internet" "red")
      ];
    })
  ];
}

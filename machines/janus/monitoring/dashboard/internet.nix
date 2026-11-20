{ ui, queries, ... }:
let
  inherit (queries) router;

  # One series per target: ISP gateway, two internet hosts, and the router's own resolver.
  probe =
    labels: pings: lookup:
    ''max by (${labels}) (${pings}{${router}, group=~"wan|internet"}) or max by (${labels}) (label_replace(label_replace(${lookup}{${router}}, "target", "resolver", "", ""), "address", "$1", "query", "(.+)"))'';
  latency = probe "target" "janus_network_probe_latency_seconds" "janus_dns_probe_latency_seconds";
in
ui.row {
  title = "Internet";
  collapsed = false;
  panels = [
    (ui.mergedTable {
      title = "Internet";
      description = "Once a minute: three pings to each address, and a lookup on the router's own resolver. Peak: the slowest answer in the picked range, beside its course.";
      w = 15;
      # Four targets, plus the title and the header.
      h = 6;
      joinBy = "target";
      sortBy = [
        {
          displayName = "Target";
          desc = false;
        }
      ];
      renamedColumns = {
        target = "Target";
        address = "Address";
      };
      firstColumns = [
        "target"
        "address"
      ];
      labelColumns = {
        Target.width = 140;
        Address.width = 130;
      };
      columns = [
        {
          name = "Up";
          width = 50;
          expr = probe "target, address" "janus_network_probe_up" "janus_dns_probe_up";
          threshold = ui.thresholds.goodWhenOne;
          valueMappings = ui.mappings.dot;
        }
        {
          name = "Latency";
          width = 90;
          expr = latency;
          unit = "s";
        }
        {
          name = "Loss";
          width = 70;
          expr = ''max by (target) (janus_network_probe_packet_loss_ratio{${router}, group=~"wan|internet"})'';
          unit = "percentunit";
          valueMappings = ui.mappings.blankZero;
        }
        {
          name = "Peak";
          expr = latency;
          unit = "s";
          sparkline = ui.colours.response;
        }
      ];
    })
    (ui.stateTimeline {
      title = "Answering";
      w = 9;
      h = 6;
      targets = [
        (ui.target (probe "target" "janus_network_probe_up" "janus_dns_probe_up") "{{target}}")
      ];
      threshold = ui.thresholds.goodWhenOne;
      valueMappings = ui.mappings.upDown;
    })
  ];
}

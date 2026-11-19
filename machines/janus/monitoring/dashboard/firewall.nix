{
  ui,
  network,
  queries,
}:
let
  logged = ''{${queries.router}, transport="kernel"} |= "janus-fw "'';
  # A packet the input chain refuses was for the router itself.
  refused = ''${logged} | regexp `janus-fw (?P<chain>[a-z]+)-drop IN=(?P<network>\S*) .*SRC=(?P<from>\S+) DST=(?P<to>\S+) .*PROTO=(?P<protocol>\S+)( SPT=\d+ DPT=(?P<port>\d+))?` | label_format to=`{{ if eq .chain "input" }}${network.instance}{{ else }}{{ .to }}{{ end }}`'';
in
ui.row {
  title = "Firewall";
  panels = [
    (ui.mergedTable {
      title = "Refused";
      description = "What the firewall refused in the picked time range, by its log, which takes at most six lines a minute. Broadcasts and the devices' discovery chatter it drops without a line.";
      w = 24;
      h = 10;
      datasource = ui.loki;
      sortBy = [
        {
          displayName = "Count";
          desc = true;
        }
      ];
      renamedColumns = {
        network = "Network";
        from = "From";
        to = "To";
        protocol = "Protocol";
        port = "Port";
      };
      firstColumns = [
        "network"
        "from"
        "to"
        "protocol"
        "port"
      ];
      labelColumns = {
        Network.valueMappings = queries.networkNames;
        From.valueMappings = queries.hostNames;
        To.valueMappings = queries.hostNames;
        Protocol.width = 90;
        Port.width = 80;
      };
      columns = [
        {
          name = "Count";
          width = 80;
          expr = "sum by (network, from, to, protocol, port) (count_over_time(${refused} [$__range]))";
        }
      ];
    })
    (ui.logs {
      title = "Recent refusals";
      w = 24;
      h = 10;
      expr = logged;
    })
  ];
}

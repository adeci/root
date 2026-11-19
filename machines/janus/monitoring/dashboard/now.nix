{ ui, queries, ... }:
let
  client = "network, address, mac";
in
ui.row {
  title = "Now";
  collapsed = false;
  panels = [
    (ui.alerts {
      w = 14;
      h = 5;
      matchers = queries.router;
    })
    (ui.mergedTable {
      title = "New clients";
      description = "Clients that got an address from the router in the last day and in none of the six days before.";
      w = 10;
      h = 5;
      datasource = ui.loki;
      noDataText = "No client is new today";
      sortBy = [
        {
          displayName = "First seen";
          desc = true;
        }
      ];
      renamedColumns = {
        network = "Network";
        address = "Address";
        mac = "MAC";
      };
      firstColumns = [
        "network"
        "address"
        "mac"
      ];
      labelColumns.Network.valueMappings = queries.networkNames;
      columns = [
        {
          name = "First seen";
          expr = "1000 * (min by (${client}) (min_over_time(${queries.leaseTimes} [24h])) and on (mac) (${queries.newClients client}))";
          unit = "dateTimeFromNow";
        }
      ];
    })
  ];
}

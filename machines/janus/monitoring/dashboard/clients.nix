{ ui, queries, ... }:
let
  client = "network, address, name, mac";
in
ui.row {
  title = "Clients";
  collapsed = false;
  panels = [
    (ui.mergedTable {
      title = "Clients";
      description = "Every client that got an address from the router in the picked time range, by its DHCP log. Name is the inventory's, for a reserved address. Here marks a client still holding its lease: leases last two hours, and clients renew them every hour. New marks one first seen today.";
      w = 24;
      # About twenty-five clients a day, plus the title and the header.
      h = 27;
      datasource = ui.loki;
      sortBy = [
        {
          displayName = "Address";
          desc = false;
        }
      ];
      renamedColumns = {
        network = "Network";
        address = "Address";
        name = "Name";
        mac = "MAC";
      };
      firstColumns = [
        "network"
        "address"
        "name"
        "mac"
      ];
      labelColumns = {
        Network.valueMappings = queries.networkNames;
        # An address without a reservation has no name.
        Name.valueMappings = queries.hostNames ++ [
          {
            type = "regex";
            options = {
              pattern = ".*";
              result.text = "";
            };
          }
        ];
      };
      columns = [
        {
          name = "Here";
          width = 60;
          expr = "count by (${client}) (count_over_time(${queries.leases} [2h]))";
          threshold = ui.thresholds.goodWhenOne;
          valueMappings = ui.mappings.dot;
        }
        {
          name = "Last seen";
          width = 150;
          expr = "1000 * max by (${client}) (max_over_time(${queries.leaseTimes} [$__range]))";
          unit = "dateTimeFromNow";
        }
        {
          name = "New";
          width = 70;
          expr = queries.newClients client;
          valueMappings = ui.mappings.new;
        }
      ];
    })
  ];
}

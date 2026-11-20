{
  ui,
  network,
  queries,
}:
let
  client = "network, address, mac";
in
ui.row {
  title = "Clients";
  collapsed = false;
  panels = [
    (ui.mergedTable {
      title = "Clients";
      description = "Every client that got an address from the router in the picked time range, by its DHCP log. Name is the inventory's for a reserved address, or else the one the client asked with, except on other people's networks, or else, in brackets, the maker its MAC names. Access point and Signal: where a Wi-Fi client is connected now, beside the address it holds now, and how strongly that access point hears it. Here marks a client that holds a lease from the router now: a lease lasts two hours from its last renewal, unless the client gives it back. New marks a device NewDevice has reported in the last day: its first lease in ${toString network.newDeviceDays} days, on the household's own networks.";
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
        access_point = "Access point";
      };
      firstColumns = [
        "network"
        "address"
        "name"
        "mac"
        "access_point"
      ];
      labelColumns = {
        Network.valueMappings = queries.networkNames;
        Name.valueMappings = queries.hostNames;
        "Access point".width = 110;
      };
      columns = [
        {
          name = "Signal";
          width = 80;
          datasource = ui.prometheus;
          # Each client once: on the access point that hears it best, as one it has just left may still list it, and beside its newest lease, as one on another network may not have expired yet.
          expr = ''max by (mac, access_point, address) (label_replace(topk by (mac) (1, janus_routeros_wifi_client_signal_dbm{${queries.router}}), "access_point", "$1", "name", "(.+)") * on (mac) group_left (address) group by (mac, address) (topk by (mac) (1, janus_dhcp_lease_renewed_timestamp_seconds{${queries.router}})))'';
          unit = "dBm";
        }
        {
          name = "Here";
          width = 60;
          datasource = ui.prometheus;
          expr = ''count by (${client}) (label_replace(janus_dhcp_lease_renewed_timestamp_seconds{${queries.router}}, "network", "$1", "address", "(.+)[.][0-9]+"))'';
          threshold = ui.thresholds.goodWhenOne;
          valueMappings = ui.mappings.dot;
        }
        {
          name = "Reserved names";
          hidden = true;
          expr = "count by (address, mac, name) (count_over_time(${queries.reservedLeases} [$__range]))";
        }
        {
          name = "Lease names";
          hidden = true;
          datasource = ui.prometheus;
          # Unreserved leases renewed within the range, each under its newest name: a reserved address has its name above, and a client that left just before the range would be a row with nothing but a name.
          expr = "topk by (address, mac) (1, max by (address, mac, name) (${queries.leaseName ''last_over_time(janus_dhcp_lease_renewed_timestamp_seconds{${queries.router}, address!~"${queries.reservedAddresses}"}[$__range]) > time() - $__range_s''}))";
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
          datasource = ui.prometheus;
          expr = "group by (address, mac) (${network.newDevices "24h"})";
          valueMappings = ui.mappings.new;
        }
      ];
    })
  ];
}

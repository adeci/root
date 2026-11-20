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
      description = "DHCP clients in the picked range, by the DHCP log. Name: the inventory's for a reserved address, else the one the client asked with (not on other people's networks), else (MAC maker). Access point and Signal: the Wi-Fi client's AP now, beside its current address, and how strongly that AP hears it. Here: holds a lease now; leases last two hours from the last renewal unless released. New: reported by NewDevice in the last day, first lease in ${toString network.newDeviceDays} days on own networks.";
      w = 24;
      # ~25 clients a day, plus title and header.
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
          # One row per client: the AP that hears it best (the old one may still list it), newest lease.
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
          # Unreserved leases renewed in range, by newest name; reserved ones are named above.
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

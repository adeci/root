{
  ui,
  network,
  queries,
}:
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
      description = "Devices NewDevice reported in the last day: first lease in ${toString network.newDeviceDays} days on own networks. Name: the one it asked with, else (MAC maker).";
      w = 10;
      h = 5;
      noDataText = "No device is new, or there are not yet ${toString network.newDeviceDays} days of lease records to tell";
      sortBy = [
        {
          displayName = "First seen";
          desc = true;
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
      columns = [
        {
          name = "First seen";
          expr = "1000 * min by (network, address, name, mac) (${queries.leaseName (network.newDevices "24h")})";
          unit = "dateTimeFromNow";
        }
      ];
    })
  ];
}

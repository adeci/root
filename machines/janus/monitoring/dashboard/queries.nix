# Queries and names several sections share.
network:
let
  inherit (network) vlans;

  router = ''instance="${network.instance}"'';
  named = name: expr: ''label_replace(${expr}, "network", "${name}", "", "")'';
  # Each VLAN's name by one of its properties, e.g. its interface.
  vlansBy =
    property:
    builtins.listToAttrs (
      map (vlan: {
        name = vlan.${property};
        value = vlan.name;
      }) vlans
    );
  # A value mapping that shows each key as its text.
  showAs = names: [
    {
      type = "value";
      options = builtins.mapAttrs (_: text: { inherit text; }) names;
    }
  ];

  # Each lease the router's DHCP server hands out or renews: the client's MAC and address, the address's first three octets as `network`, and the address again as `name`, for a table to show as the inventory names it.
  leases = ''{${router}, service_name="kea-dhcp4-server.service"} |~ "DHCP4_LEASE_(ALLOC|REUSE)" | regexp `hwtype=1 (?P<mac>[0-9a-f:]+)\].* lease (?P<address>(?P<network>[0-9]+[.][0-9]+[.][0-9]+)[.][0-9]+) has been` | label_format name="{{.address}}"'';
in
{
  inherit
    router
    named
    showAs
    leases
    ;
  mikrotik = ''${router}, job="mikrotik"'';

  # One query per VLAN, its series named after the VLAN as `network`, joined with `or`.
  perVlan = query: builtins.concatStringsSep " or " (map (vlan: named vlan.name (query vlan)) vlans);

  # A network's name for the router's interface on it, or for the first three octets of its addresses.
  networkNames = showAs (
    vlansBy "interface" // vlansBy "prefix" // { ${network.interfaces.wan} = "internet"; }
  );
  # A reserved address's host, or the router for a VLAN's gateway.
  hostNames = showAs (
    network.hostsByAddress // builtins.mapAttrs (_: _: network.instance) (vlansBy "gateway")
  );

  # The time of each lease, to unwrap.
  leaseTimes = "${leases} | label_format seen=`{{ __timestamp__ | unixEpoch }}` | unwrap seen";
  # 1 for each client that got a lease in the last day and none in the six days before.
  newClients =
    labels:
    "count by (${labels}) (count_over_time(${leases} [24h])) unless on (mac) count by (mac) (count_over_time(${leases} [6d] offset 24h))";
}

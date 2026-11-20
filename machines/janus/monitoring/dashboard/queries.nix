# Queries and names several sections share.
network:
let
  inherit (network) vlans reservedAddresses;

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

  # Each lease the router's DHCP server hands out or renews: the client's MAC and address, and the address's first three octets as `network`.
  leases = ''{${router}, service_name="kea-dhcp4-server.service"} |~ "DHCP4_LEASE_(ALLOC|REUSE)" | regexp `hwtype=1 (?P<mac>[0-9a-f:]+)\].* lease (?P<address>(?P<network>[0-9]+[.][0-9]+[.][0-9]+)[.][0-9]+) has been`'';
in
{
  inherit
    router
    named
    showAs
    leases
    reservedAddresses
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
  # The leases of reserved addresses, with the address again as `name`, for a table to show as the inventory names it.
  reservedLeases = ''${leases} | address =~ "${reservedAddresses}" | label_format name="{{.address}}"'';
  # Lease series with a `name` to show: the one the client asked with, or else, in brackets, the maker its MAC names.
  leaseName =
    expr:
    ''label_replace(label_replace(${expr}, "name", "($1)", "maker", "(.+)"), "name", "$1", "hostname", "(.+)")'';
}

# PromQL several sections share.
{ ui, network }:
let
  inherit (network) interfaces vlans;

  router = ''instance="${network.instance}"'';
  internet = ''${router},job="smokeping",group="internet"'';

  oneOf = builtins.concatStringsSep "|";

  received =
    device: ''rate(node_network_receive_bytes_total{${router},device="${device}"}[$__rate_interval])'';
  transmitted =
    device: ''rate(node_network_transmit_bytes_total{${router},device="${device}"}[$__rate_interval])'';

  # Every panel gives a VLAN the same colour.
  palette = [
    "green"
    "yellow"
    "orange"
    "purple"
    "light-red"
    "cyan"
    "dark-green"
    "dark-yellow"
  ];
  colour =
    index: builtins.elemAt palette (index - index / builtins.length palette * builtins.length palette);
in
{
  inherit
    router
    internet
    received
    transmitted
    ;

  total = device: "${received device} + ${transmitted device}";
  bps = expr: "8 * (${expr})";

  # The WAN, the LAN trunk and each VLAN's gateway interface.
  routedInterfaces = oneOf (
    [
      interfaces.wan
      interfaces.lan
    ]
    ++ map (vlan: vlan.interface) vlans
  );
  subnetIds = oneOf (map (vlan: toString vlan.id) vlans);

  cpu = ''100 * (1 - avg(rate(node_cpu_seconds_total{${router},mode="idle"}[$__rate_interval])))'';

  internetLatency = quantile: ''
    (1000 * histogram_quantile(${quantile}, sum by (le) (rate(smokeping_response_duration_seconds_bucket{${internet}}[$__rate_interval]))))
    or vector(0)
  '';
  internetLoss = ''
    100 * (
      1 - (
        sum(rate(smokeping_response_duration_seconds_count{${internet}}[$__rate_interval]))
        /
        clamp_min(sum(rate(smokeping_requests_total{${internet}}[$__rate_interval])), 0.001)
      )
    )
  '';

  # One query per VLAN, named after it.
  vlanTargets = query: map (vlan: ui.target (query vlan) vlan.name) vlans;
  vlanColours = builtins.genList (
    index: ui.colorOverride (builtins.elemAt vlans index).name (colour index)
  ) (builtins.length vlans);
}

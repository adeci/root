{
  clan-cli,
  config,
  lib,
  self,
  ...
}:
let
  inherit (import ../lib.nix { inherit clan-cli lib; }) safeName;
  inherit (self.inventory) ingress tailnet;
  inherit (self.inventory.cloudflare) dns redirects zones;
  inherit (import ./lib.nix { inherit lib zones; }) zoneOf;

  edgeAddress =
    edgeName:
    let
      edge = ingress.edges.${edgeName};
    in
    if edge.provider == "hcloud" then
      config.resource.hcloud_server.${edgeName} "ipv4_address"
    else
      throw "Cloudflare DNS edge target ${edgeName}: unsupported provider ${edge.provider}";

  # references.nix checks that the stream exists.
  ingressStream =
    reference:
    lib.findFirst (stream: stream.name == reference.name) null ingress.streams.${reference.edge};
in
{
  resource.cloudflare_dns_record = lib.mkMerge [
    (lib.mapAttrs (
      _: record:
      # Automatic TTL: provider v4 assumed it, v5 wants it explicit.
      {
        ttl = 1;
      }
      // removeAttrs record [
        "host"
        "target"
        "edge"
        "tailnet"
        "ingressStream"
        "healthPath"
      ]
      // {
        zone_id = config.data.cloudflare_zone.${safeName (zoneOf record.host)} "id";
        name = record.host;
      }
      // lib.optionalAttrs (record ? target) {
        content = config.resource.${record.target.resource}.${record.target.name} record.target.field;
      }
      // lib.optionalAttrs (record ? edge) {
        content = edgeAddress record.edge;
      }
      // lib.optionalAttrs (record ? tailnet) {
        content = tailnet.addresses.${record.tailnet};
      }
      // lib.optionalAttrs (record ? ingressStream) {
        data = (record.data or { }) // {
          port = (ingressStream record.ingressStream).listen;
        };
      }
      # Cloudflare repeats SRV priority at top level; v5 would plan to clear it otherwise.
      // lib.optionalAttrs (record ? data.priority) {
        inherit (record.data) priority;
      }
    ) dns)

    # Placeholders for the redirects in rulesets.nix; 100:: is Cloudflare's originless address.
    (lib.mapAttrs' (
      _: redirect:
      lib.nameValuePair "redirect_${safeName redirect.host}" {
        zone_id = config.data.cloudflare_zone.${safeName (zoneOf redirect.host)} "id";
        name = redirect.host;
        type = "AAAA";
        content = "100::";
        proxied = true;
        ttl = 1;
      }
    ) redirects)
  ];
}

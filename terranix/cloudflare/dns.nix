{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (import ../lib.nix { inherit config lib self'; }) safeName;
  inherit (self.inventory) ingress;
  inherit (self.inventory.cloudflare) dns redirects zones;
  inherit (import ./lib.nix { inherit lib zones; }) recordName zoneOf;

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
  resource.cloudflare_record = lib.mkMerge [
    (lib.mapAttrs (
      _: record:
      removeAttrs record [
        "host"
        "target"
        "edge"
        "ingressStream"
        "healthPath"
      ]
      // {
        zone_id = config.data.cloudflare_zone.${safeName (zoneOf record.host)} "id";
        name = recordName record.host;
      }
      // lib.optionalAttrs (record ? target) {
        content = config.resource.${record.target.resource}.${record.target.name} record.target.field;
      }
      // lib.optionalAttrs (record ? edge) {
        content = edgeAddress record.edge;
      }
      // lib.optionalAttrs (record ? ingressStream) {
        data = (record.data or { }) // {
          port = (ingressStream record.ingressStream).listen;
        };
      }
    ) dns)

    # Placeholders for the redirects in rulesets.nix; 100:: is Cloudflare's originless address.
    (lib.mapAttrs' (
      _: redirect:
      lib.nameValuePair "redirect_${safeName redirect.host}" {
        zone_id = config.data.cloudflare_zone.${safeName (zoneOf redirect.host)} "id";
        name = recordName redirect.host;
        type = "AAAA";
        content = "100::";
        proxied = true;
      }
    ) redirects)
  ];
}

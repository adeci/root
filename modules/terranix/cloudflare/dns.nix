# Cloudflare DNS records
# Merges tunnel CNAMEs (auto-generated) with standalone records from inventory.
{
  config,
  self,
  lib,
  ...
}:
let
  inherit (self.resources.cloudflare) zones tunnels dns;

  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
  zoneRef = zone: config.data.cloudflare_zone.${safeName zone} "id";

  # Split hostname into name + zone.
  # "vault.decio.us" → { name = "vault"; zone = "decio.us"; }
  # "decio.us"       → { name = "@";     zone = "decio.us"; }
  splitHostname =
    hostname:
    let
      matchedZone = lib.findFirst (z: lib.hasSuffix z hostname) null zones;
      name = if hostname == matchedZone then "@" else lib.removeSuffix ".${matchedZone}" hostname;
    in
    {
      inherit name;
      zone = matchedZone;
    };

  # Resolve a symbolic target reference to a terraform expression.
  # { resource = "hcloud_server"; name = "conduit"; field = "ipv4_address"; }
  resolveTarget = target: config.resource.${target.resource}.${target.name} target.field;

  edgeAddress =
    edgeName:
    let
      edge = self.resources.ingress.edges.${edgeName};
    in
    if edge.provider == "hcloud" then
      config.resource.hcloud_server.${edgeName} "ipv4_address"
    else
      throw "Cloudflare DNS edge target ${edgeName}: unsupported provider ${edge.provider}";

  ingressStream =
    ref:
    let
      matches = lib.filter (stream: stream.name == ref.name) (
        self.resources.ingress.streams.${ref.edge} or [ ]
      );
    in
    if lib.length matches == 1 then
      builtins.head matches
    else if matches == [ ] then
      throw "Cloudflare DNS ingress stream ${ref.edge}/${ref.name}: no matching stream"
    else
      throw "Cloudflare DNS ingress stream ${ref.edge}/${ref.name}: duplicate stream name";
in
{
  resource.cloudflare_record =
    let
      # Tunnel CNAME records (auto-generated from tunnel definitions)
      tunnelRecords = lib.concatMapAttrs (
        machine: ingress:
        lib.mapAttrs' (
          hostname: _:
          let
            parts = splitHostname hostname;
          in
          lib.nameValuePair "tunnel_${safeName hostname}" {
            zone_id = zoneRef parts.zone;
            inherit (parts) name;
            type = "CNAME";
            content = "${config.resource.cloudflare_tunnel.${machine} "id"}.cfargotunnel.com";
            proxied = true;
          }
        ) ingress
      ) tunnels;

      # Standalone DNS records from self.resources.cloudflare.dns.
      # Convenience fields:
      # - zone -> zone_id lookup
      # - target -> arbitrary Terraform resource field
      # - edge -> public edge IPv4 address
      # - ingressStream -> SRV port from public L4 stream data
      dnsRecords = lib.mapAttrs (
        _: record:
        let
          stream = if record ? ingressStream then ingressStream record.ingressStream else null;
          passthrough = removeAttrs record [
            "zone"
            "target"
            "edge"
            "ingressStream"
          ];
        in
        passthrough
        // {
          zone_id = zoneRef record.zone;
        }
        // lib.optionalAttrs (record ? target) {
          content = resolveTarget record.target;
        }
        // lib.optionalAttrs (record ? edge) {
          content = edgeAddress record.edge;
        }
        // lib.optionalAttrs (stream != null) {
          data = (record.data or { }) // {
            port = stream.listen;
          };
        }
      ) dns;
    in
    tunnelRecords // dnsRecords;
}

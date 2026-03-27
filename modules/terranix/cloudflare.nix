# Cloudflare provider logic
# Data layer consumed thru self.resources.cloudflare.{zones,tunnels,dns,...}
{
  config,
  self,
  self',
  inputs',
  lib,
  ...
}:
let
  inherit (self.resources.cloudflare) zones tunnels dns;
  inherit (inputs'.clan-core.packages) clan-cli;

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

  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];

  zoneRef = zone: config.data.cloudflare_zone.${safeName zone} "id";

  # Resolve a symbolic target reference to a terraform expression.
  # { resource = "hcloud_server"; name = "conduit"; field = "ipv4_address"; }
  # becomes config.resource.hcloud_server.conduit "ipv4_address"
  resolveTarget = target: config.resource.${target.resource}.${target.name} target.field;
in
{
  # ── Provider + zones ────────────────────────────────────────────────

  terraform.required_providers.cloudflare = {
    source = "cloudflare/cloudflare";
    version = "~> 4.0";
  };

  terraform.required_providers.random = {
    source = "hashicorp/random";
  };

  data.external.cloudflare-api-token = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "cloudflare-api-token"
    ];
  };

  data.external.cloudflare-account-id = {
    program = [
      (lib.getExe self'.packages.get-clan-secret)
      "cloudflare-account-id"
    ];
  };

  provider.cloudflare = {
    api_token = config.data.external.cloudflare-api-token "result.secret";
  };

  # Zone data sources — generated from self.resources.cloudflare.zones
  data.cloudflare_zone = lib.listToAttrs (
    map (zone: {
      name = safeName zone;
      value = {
        name = zone;
      };
    }) zones
  );

  # ── Tunnels ─────────────────────────────────────────────────────────

  resource.random_id = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_secret_${machine}" {
      byte_length = 32;
    }
  ) tunnels;

  resource.cloudflare_tunnel = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair machine {
      account_id = config.data.external.cloudflare-account-id "result.secret";
      name = machine;
      secret = config.resource.random_id."tunnel_secret_${machine}" "b64_std";
      config_src = "cloudflare";
    }
  ) tunnels;

  resource.cloudflare_tunnel_config = lib.mapAttrs' (
    machine: ingress:
    lib.nameValuePair machine {
      account_id = config.data.external.cloudflare-account-id "result.secret";
      tunnel_id = config.resource.cloudflare_tunnel.${machine} "id";

      config.ingress_rule =
        (lib.mapAttrsToList (hostname: service: {
          inherit hostname service;
        }) ingress)
        ++ [
          { service = "http_status:404"; }
        ];
    }
  ) tunnels;

  # ── DNS records ─────────────────────────────────────────────────────

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

      # Standalone DNS records from self.resources.cloudflare.dns
      # Two conveniences: "zone" → zone_id lookup, "target" → resolved terraform ref.
      # Everything else passes through to the cloudflare_record resource as-is.
      dnsRecords = lib.mapAttrs (
        _: record:
        let
          # Strip our convenience fields, keep everything else
          passthrough = removeAttrs record [
            "zone"
            "target"
          ];
        in
        passthrough
        // {
          zone_id = zoneRef record.zone;
        }
        // lib.optionalAttrs (record ? target) {
          content = resolveTarget record.target;
        }
      ) dns;
    in
    tunnelRecords // dnsRecords;

  # ── Tunnel token thru clan vars ────────────────────────────────────────

  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_token_${machine}" {
      input = config.resource.cloudflare_tunnel.${machine} "tunnel_token";

      provisioner.local-exec = {
        command = "echo \"\${self.input}\" | ${lib.getExe clan-cli} vars set ${machine} cloudflare-tunnel-token/token";
      };
    }
  ) tunnels;
}

{
  config,
  self',
  inputs',
  lib,
  ...
}:
let
  tunnels = import ../../inventory/tunnels.nix;

  # Split hostname into name + zone
  # "vault.decio.us" → { name = "vault"; zone = "decio.us"; }
  # "decio.us" → { name = "@"; zone = "decio.us"; }
  # "adeci.dev" → { name = "@"; zone = "adeci.dev"; }
  splitHostname =
    hostname:
    let
      zones = [
        "decio.us"
        "adeci.dev"
      ];
      matchedZone = lib.findFirst (z: lib.hasSuffix z hostname) null zones;
      name = if hostname == matchedZone then "@" else lib.removeSuffix ".${matchedZone}" hostname;
    in
    {
      inherit name;
      zone = matchedZone;
    };

  # Generate a safe terraform resource name from a hostname
  safeName = hostname: builtins.replaceStrings [ "." "-" ] [ "_" "_" ] hostname;

  inherit (inputs'.clan-core.packages) clan-cli;
in
{
  terraform.required_providers.cloudflare = {
    source = "cloudflare/cloudflare";
    version = "~> 4.0";
  };

  # Cloudflare credentials from clan secrets
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

  # Zone data sources
  data.cloudflare_zone.decio_us = {
    name = "decio.us";
  };

  data.cloudflare_zone.adeci_dev = {
    name = "adeci.dev";
  };

  # ── Tunnels ──────────────────────────────────────────────────────────

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

  # ── Tunnel DNS records ──────────────────────────────────────────────

  resource.cloudflare_record =
    let
      # Tunnel CNAME records
      tunnelRecords = lib.concatMapAttrs (
        machine: ingress:
        lib.mapAttrs' (
          hostname: _:
          let
            parts = splitHostname hostname;
            zoneRef =
              if parts.zone == "decio.us" then
                config.data.cloudflare_zone.decio_us "id"
              else
                config.data.cloudflare_zone.adeci_dev "id";
          in
          lib.nameValuePair "tunnel_${safeName hostname}" {
            zone_id = zoneRef;
            inherit (parts) name;
            type = "CNAME";
            content = "${config.resource.cloudflare_tunnel.${machine} "id"}.cfargotunnel.com";
            proxied = true;
          }
        ) ingress
      ) tunnels;

      # ── Minecraft A records (point to conduit) ──────────────────────

      minecraftRecords = {
        mc_rlc = {
          zone_id = config.data.cloudflare_zone.decio_us "id";
          name = "rlc";
          type = "A";
          content = config.resource.hcloud_server.conduit "ipv4_address";
        };
        mc_rats = {
          zone_id = config.data.cloudflare_zone.decio_us "id";
          name = "rats";
          type = "A";
          content = config.resource.hcloud_server.conduit "ipv4_address";
        };
        mc_dj2 = {
          zone_id = config.data.cloudflare_zone.decio_us "id";
          name = "dj2";
          type = "A";
          content = config.resource.hcloud_server.conduit "ipv4_address";
        };
        mc_bruh = {
          zone_id = config.data.cloudflare_zone.decio_us "id";
          name = "bruh";
          type = "A";
          content = config.resource.hcloud_server.conduit "ipv4_address";
        };
      };

      # ── Minecraft SRV records ───────────────────────────────────────

      srvRecords = {
        srv_rlc = {
          zone_id = config.data.cloudflare_zone.decio_us "id";
          name = "_minecraft._tcp.rlc";
          type = "SRV";
          data = {
            priority = 0;
            weight = 0;
            port = 25565;
            target = "rlc.decio.us";
          };
        };
        srv_rats = {
          zone_id = config.data.cloudflare_zone.decio_us "id";
          name = "_minecraft._tcp.rats";
          type = "SRV";
          data = {
            priority = 0;
            weight = 0;
            port = 25566;
            target = "rats.decio.us";
          };
        };
        srv_dj2 = {
          zone_id = config.data.cloudflare_zone.decio_us "id";
          name = "_minecraft._tcp.dj2";
          type = "SRV";
          data = {
            priority = 0;
            weight = 0;
            port = 25568;
            target = "dj2.decio.us";
          };
        };
      };

    in
    tunnelRecords // minecraftRecords // srvRecords;

  # ── Tunnel token → clan vars via local-exec ─────────────────────────

  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_token_${machine}" {
      input = config.resource.cloudflare_tunnel.${machine} "tunnel_token";

      provisioner.local-exec = {
        command = "echo \"\${self.input}\" | ${lib.getExe clan-cli} vars set ${machine} cloudflare-tunnel-token/token";
      };
    }
  ) tunnels;

  # Required for tunnel secrets
  terraform.required_providers.random = {
    source = "hashicorp/random";
  };
}

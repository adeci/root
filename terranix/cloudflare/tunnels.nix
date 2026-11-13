{
  config,
  lib,
  self,
  self',
  ...
}:
let
  inherit (import ../lib.nix { inherit config lib self'; }) clanSecret safeName setClanVar;
  inherit (self.inventory.cloudflare) tunnels tunnelToken zones;
  inherit (import ./lib.nix { inherit lib zones; }) recordName zoneOf;

  tunnelId = machine: config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id";
in
{
  # random_bytes, not random_id: random_id exposes the secret as its id.
  resource.random_bytes = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_secret_${machine}" {
      length = 32;
    }
  ) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared = lib.mapAttrs (machine: _: {
    account_id = clanSecret "cloudflare-account-id";
    name = machine;
    secret = config.resource.random_bytes."tunnel_secret_${machine}" "base64";
    config_src = "cloudflare";
  }) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared_config = lib.mapAttrs (machine: routes: {
    account_id = clanSecret "cloudflare-account-id";
    tunnel_id = tunnelId machine;

    config.ingress_rule =
      lib.mapAttrsToList (hostname: route: {
        inherit hostname;
        service = "http://localhost:${toString route.port}";
      }) routes
      ++ [
        { service = "http_status:404"; }
      ];
  }) tunnels;

  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_token_${machine}" {
      input = tunnelId machine;
      triggers_replace = [ (tunnelId machine) ];

      provisioner.local-exec = {
        # terraform_data echoes its input unredacted, so the token goes only to the provisioner.
        environment.TUNNEL_TOKEN = "\${sensitive(cloudflare_zero_trust_tunnel_cloudflared.${machine}.tunnel_token)}";
        command = ''
          printf '%s\n' "$TUNNEL_TOKEN" | ${setClanVar machine tunnelToken}
        '';
      };
    }
  ) tunnels;

  resource.cloudflare_record = lib.concatMapAttrs (
    machine: routes:
    lib.mapAttrs' (
      hostname: _:
      lib.nameValuePair "tunnel_${safeName hostname}" {
        zone_id = config.data.cloudflare_zone.${safeName (zoneOf hostname)} "id";
        name = recordName hostname;
        type = "CNAME";
        content = "${tunnelId machine}.cfargotunnel.com";
        proxied = true;
      }
    ) routes
  ) tunnels;
}

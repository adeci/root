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
  inherit (import ./lib.nix { inherit lib zones; }) zoneOf;

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
    tunnel_secret = config.resource.random_bytes."tunnel_secret_${machine}" "base64";
    config_src = "cloudflare";
  }) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared_config = lib.mapAttrs (machine: routes: {
    account_id = clanSecret "cloudflare-account-id";
    tunnel_id = tunnelId machine;

    # In the order of the names, so renaming a service leaves the rules where they are.
    config.ingress =
      map (route: {
        hostname = route.host;
        service = "http://localhost:${toString route.port}";
      }) (lib.sortOn (route: route.host) (lib.attrValues routes))
      ++ [
        { service = "http_status:404"; }
      ];

    # Cloudflare still returns the empty origin_request provider v4 always sent; leaving it out would plan a change to every tunnel.
    config.origin_request = { };
  }) tunnels;

  # Provider v5 no longer gives the token on the tunnel itself.
  data.cloudflare_zero_trust_tunnel_cloudflared_token = lib.mapAttrs (machine: _: {
    account_id = clanSecret "cloudflare-account-id";
    tunnel_id = tunnelId machine;
  }) tunnels;

  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_token_${machine}" {
      input = tunnelId machine;
      triggers_replace = [ (tunnelId machine) ];

      provisioner.local-exec = {
        # terraform_data echoes its input unredacted, so the token goes only to the provisioner.
        environment.TUNNEL_TOKEN = "\${sensitive(data.cloudflare_zero_trust_tunnel_cloudflared_token.${machine}.token)}";
        command = ''
          printf '%s\n' "$TUNNEL_TOKEN" | ${setClanVar machine tunnelToken}
        '';
      };
    }
  ) tunnels;

  resource.cloudflare_dns_record = lib.concatMapAttrs (
    machine: routes:
    lib.mapAttrs' (
      _: route:
      lib.nameValuePair "tunnel_${safeName route.host}" {
        zone_id = config.data.cloudflare_zone.${safeName (zoneOf route.host)} "id";
        name = route.host;
        type = "CNAME";
        content = "${tunnelId machine}.cfargotunnel.com";
        proxied = true;
        ttl = 1;
      }
    ) routes
  ) tunnels;
}

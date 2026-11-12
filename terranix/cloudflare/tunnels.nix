{
  config,
  self,
  lib,
  clanSecret,
  setClanVar,
  ...
}:
let
  inherit (self.resources.cloudflare) tunnels tunnelToken;
in
{
  # random_bytes, not random_id: random_id exposes the secret as its id.
  resource.random_bytes = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_secret_${machine}" {
      length = 32;
    }
  ) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair machine {
      account_id = clanSecret "cloudflare-account-id";
      name = machine;
      secret = config.resource.random_bytes."tunnel_secret_${machine}" "base64";
      config_src = "cloudflare";
    }
  ) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared_config = lib.mapAttrs' (
    machine: ingress:
    lib.nameValuePair machine {
      account_id = clanSecret "cloudflare-account-id";
      tunnel_id = config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id";

      config.ingress_rule =
        (lib.mapAttrsToList (hostname: route: {
          inherit hostname;
          service = "http://localhost:${toString route.port}";
        }) ingress)
        ++ [
          { service = "http_status:404"; }
        ];
    }
  ) tunnels;

  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    let
      tunnelId = config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id";
    in
    lib.nameValuePair "tunnel_token_${machine}" {
      input = tunnelId;
      triggers_replace = [ tunnelId ];

      provisioner.local-exec = {
        # terraform_data echoes its input unredacted, so only the tunnel ID goes there; the token goes straight to the provisioner.
        environment.TUNNEL_TOKEN = "\${sensitive(cloudflare_zero_trust_tunnel_cloudflared.${machine}.tunnel_token)}";
        command = ''
          printf '%s\n' "$TUNNEL_TOKEN" | ${setClanVar machine tunnelToken}
        '';
      };
    }
  ) tunnels;
}

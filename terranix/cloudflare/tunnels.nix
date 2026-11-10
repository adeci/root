# Cloudflare tunnel resources
# Each machine in self.resources.cloudflare.tunnels gets a tunnel + config + token.
{
  config,
  self,
  inputs',
  lib,
  ...
}:
let
  inherit (self.resources.cloudflare) tunnels;
  inherit (inputs'.clan-core.packages) clan-cli;
in
{
  # random_bytes keeps the secret sensitive; random_id printed it as its id.
  resource.random_bytes = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair "tunnel_secret_${machine}" {
      length = 32;
    }
  ) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared = lib.mapAttrs' (
    machine: _:
    lib.nameValuePair machine {
      account_id = config.data.external.cloudflare-account-id "result.secret";
      name = machine;
      secret = config.resource.random_bytes."tunnel_secret_${machine}" "base64";
      config_src = "cloudflare";
    }
  ) tunnels;

  resource.cloudflare_zero_trust_tunnel_cloudflared_config = lib.mapAttrs' (
    machine: ingress:
    lib.nameValuePair machine {
      account_id = config.data.external.cloudflare-account-id "result.secret";
      tunnel_id = config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id";

      config.ingress_rule =
        (lib.mapAttrsToList (hostname: service: {
          inherit hostname service;
        }) ingress)
        ++ [
          { service = "http_status:404"; }
        ];
    }
  ) tunnels;

  # Push tunnel tokens into clan vars for NixOS consumption
  resource.terraform_data = lib.mapAttrs' (
    machine: _:
    let
      tunnelId = config.resource.cloudflare_zero_trust_tunnel_cloudflared.${machine} "id";
    in
    lib.nameValuePair "tunnel_token_${machine}" {
      input = tunnelId;
      triggers_replace = [ tunnelId ];

      provisioner.local-exec = {
        # terraform_data echoes input into output without preserving sensitivity.
        # Keep only the tunnel ID there; pass the token directly to the provisioner.
        environment.TUNNEL_TOKEN = "\${sensitive(cloudflare_zero_trust_tunnel_cloudflared.${machine}.tunnel_token)}";
        command = ''
          printf '%s\n' "$TUNNEL_TOKEN" | ${lib.getExe clan-cli} vars set ${machine} cloudflare-tunnel-token/token
        '';
      };
    }
  ) tunnels;
}

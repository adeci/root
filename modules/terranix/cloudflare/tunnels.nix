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

  # Push tunnel tokens into clan vars for NixOS consumption
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

{
  nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (config.acme) tokenGenerator;
    in
    {
      options.acme.tokenGenerator = lib.mkOption {
        type = lib.types.str;
        description = "Shared clan vars generator holding the Cloudflare DNS API token.";
      };

      config = {
        # Shared: a separate token per host would carry the same zone-wide power.
        clan.core.vars.generators.${tokenGenerator} = {
          share = true;
          files.env.secret = true;

          prompts.dns-api-token = {
            display = {
              group = "acme";
              label = "Cloudflare DNS API token";
              required = true;
            };
            description = "Cloudflare token with Zone:Read and DNS:Edit on the ACME zones";
            type = "hidden";
            persist = true;
          };

          runtimeInputs = [ pkgs.coreutils ];

          script = ''
            printf 'CF_DNS_API_TOKEN=%s\n' "$(tr -d '\n' < "$prompts/dns-api-token")" > "$out/env"
          '';
        };

        security.acme = {
          acceptTerms = true;
          defaults = {
            dnsProvider = "cloudflare";
            environmentFile = config.clan.core.vars.generators.${tokenGenerator}.files.env.path;
            extraLegoFlags = [ "--dns.propagation.disable-rns" ];
          };
        };
      };
    };
}

{ config, pkgs, ... }:
{
  # Cloudflare DNS-01 for decio.us names. Hosts declare their own
  # security.acme.certs; the provider plumbing lives here.

  # Shared: a separate token per host would carry the same zone-wide power.
  clan.core.vars.generators.cloudflare-acme-decio-us = {
    share = true;
    files.env.secret = true;

    prompts.dns-api-token = {
      display = {
        group = "acme";
        label = "Cloudflare DNS API token";
        required = true;
      };
      description = "Cloudflare token with Zone:Read and DNS:Edit for decio.us ACME";
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
      environmentFile = config.clan.core.vars.generators.cloudflare-acme-decio-us.files.env.path;
      extraLegoFlags = [ "--dns.propagation.disable-rns" ];
    };
  };
}

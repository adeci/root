{ config, pkgs, ... }:
{
  # Fleet ACME certificates. Service modules attach nginx vhosts with
  # `useACMEHost = <cert-name>` and keep certificate/provider plumbing here.

  clan.core.vars.generators.cloudflare-acme-decio-us = {
    files.env.secret = true;

    prompts.dns-api-token = {
      display = {
        group = "acme";
        label = "Cloudflare DNS API token";
        required = true;
      };
      description = "Cloudflare token with Zone:Read and DNS:Edit for decio.us wildcard ACME";
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

    certs."decio.us" = {
      extraDomainNames = [ "*.decio.us" ];
      dnsProvider = "cloudflare";
      environmentFile = config.clan.core.vars.generators.cloudflare-acme-decio-us.files.env.path;
      group = "nginx";
      reloadServices = [ "nginx.service" ];
    };
  };
}

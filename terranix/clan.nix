# Clan secrets and vars for Terraform.
{
  config,
  lib,
  self',
  ...
}:
{
  options.clanSecrets = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Clan secrets this workspace reads; read each with `clanSecret \"<name>\"`.";
  };

  config = {
    terraform.required_providers.external = {
      source = "registry.opentofu.org/hashicorp/external";
      version = "~> 2.0";
    };

    data.external = lib.genAttrs config.clanSecrets (secret: {
      program = [
        (lib.getExe self'.packages.get-clan-secret)
        secret
      ];
    });

    _module.args = {
      clanSecret = secret: config.data.external.${secret} "result.secret";

      # A command that stores its input in a machine's clan var.
      setClanVar =
        machine: var:
        "${lib.getExe self'.packages.clan-cli} vars set ${machine} ${var.generator}/${var.file}";
    };
  };
}

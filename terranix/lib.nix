{
  config,
  lib,
  self',
}:
{
  # A clan secret's value; the module lists the secret in clanSecrets.
  clanSecret = secret: config.data.external.${secret} "result.secret";

  # A command that stores its input in a machine's clan var.
  setClanVar =
    machine: var:
    "${lib.getExe self'.packages.clan-cli} vars set ${machine} ${var.generator}/${var.file}";

  # Hostnames, zones and machine names as Terraform resource names.
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
}

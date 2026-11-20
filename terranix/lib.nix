{
  clan-cli,
  lib,
}:
{
  # Plans show it as "(sensitive value)"; list the secret in clanSecrets.
  clanSecret = secret: "\${sensitive(data.external.${secret}.result.secret)}";

  # A command that stores its input in a machine's clan var.
  setClanVar =
    machine: var: "${lib.getExe clan-cli} vars set ${machine} ${var.generator}/${var.file}";

  # Hostnames, zones and machine names as Terraform resource names.
  safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
}

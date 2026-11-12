# Hostnames, zones and machine names as Terraform resource names.
{
  _module.args.safeName = builtins.replaceStrings [ "." "-" ] [ "_" "_" ];
}

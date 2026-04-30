{ lib, ... }:
let
  raw = import ../../inventory/compute;

  pad2 =
    value:
    let
      string = toString value;
    in
    if builtins.stringLength string == 1 then "0${string}" else string;

  mkTenant =
    name: tenant:
    assert lib.assertMsg (
      tenant ? id && builtins.isInt tenant.id && tenant.id > 1 && tenant.id < 100
    ) "compute tenant ${name}: id must be an integer from 2 to 99";
    let
      networkName = tenant.network or "tenant";
      network =
        raw.networks.${networkName} or (throw "Unknown compute network ${networkName} for ${name}");
    in
    tenant
    // {
      inherit name;
      network = networkName;
      tags = tenant.tags or [ "tenant-vm" ];
      lifecycle = {
        autostart = false;
        restartIfChanged = false;
      }
      // (tenant.lifecycle or { });
      mac = tenant.mac or "${network.macPrefix}:${pad2 tenant.id}";
    };
in
{
  options.flake.compute = lib.mkOption { default = { }; };

  config.flake.compute = raw // {
    tenants = lib.mapAttrs mkTenant raw.tenants;
  };
}

{ lib, ... }:
let
  raw = import ../../inventory/compute;
  clanMachines = import ../../inventory/clan/machines.nix;

  pad2 =
    value:
    let
      string = toString value;
    in
    if builtins.stringLength string == 1 then "0${string}" else string;

  duplicates =
    values:
    let
      counts = builtins.foldl' (acc: value: acc // { ${value} = (acc.${value} or 0) + 1; }) { } values;
    in
    lib.attrNames (lib.filterAttrs (_: count: count > 1) counts);

  mkInstance =
    name: instance:
    assert lib.assertMsg (
      instance ? id && builtins.isInt instance.id && instance.id > 1 && instance.id < 100
    ) "compute instance ${name}: id must be an integer from 2 to 99";
    assert lib.assertMsg (
      instance ? resources
      && instance.resources ? vcpu
      && builtins.isInt instance.resources.vcpu
      && instance.resources.vcpu > 0
    ) "compute instance ${name}: resources.vcpu must be a positive integer";
    assert lib.assertMsg (
      instance.resources ? memoryMiB
      && builtins.isInt instance.resources.memoryMiB
      && instance.resources.memoryMiB >= 256
    ) "compute instance ${name}: resources.memoryMiB must be an integer >= 256";
    let
      networkName = instance.network or "tenant";
      network =
        raw.networks.${networkName} or (throw "Unknown compute network ${networkName} for ${name}");
      bootstrap = {
        transport = "none";
        material = "none";
      }
      // (instance.bootstrap or { });
    in
    assert lib.assertMsg (builtins.elem bootstrap.transport [
      "none"
      "seed-disk"
    ]) "compute instance ${name}: bootstrap.transport must be one of: none, seed-disk";
    assert lib.assertMsg (builtins.elem bootstrap.material [
      "none"
      "clan-machine-age-key"
    ]) "compute instance ${name}: bootstrap.material must be one of: none, clan-machine-age-key";
    assert lib.assertMsg ((bootstrap.transport == "none") == (bootstrap.material == "none"))
      "compute instance ${name}: bootstrap.transport and bootstrap.material must both be none, or both be set";
    assert lib.assertMsg (
      bootstrap.material != "clan-machine-age-key" || bootstrap.transport == "seed-disk"
    ) "compute instance ${name}: clan-machine-age-key bootstrap currently requires seed-disk transport";
    instance
    // {
      inherit name bootstrap;
      network = networkName;
      lifecycle = {
        autostart = false;
        restartIfChanged = false;
      }
      // (instance.lifecycle or { });
      mac = instance.mac or "${network.macPrefix}:${pad2 instance.id}";
    };

  instances = lib.mapAttrs mkInstance raw.instances;

  assignedInstanceNames = lib.concatLists (lib.attrValues raw.assignments);
  assignmentHosts = lib.attrNames raw.assignments;

  unknownAssignmentHosts = lib.filter (host: !(builtins.hasAttr host raw.hosts)) assignmentHosts;
  unknownAssignedInstances = lib.filter (
    name: !(builtins.hasAttr name raw.instances)
  ) assignedInstanceNames;
  duplicateAssignments = duplicates assignedInstanceNames;
  instancesWithoutClanMachine = lib.filter (name: !(builtins.hasAttr name clanMachines)) (
    lib.attrNames raw.instances
  );
  instancesWithoutMachineConfig = lib.filter (
    name: !(builtins.pathExists (../../machines + "/${name}/configuration.nix"))
  ) (lib.attrNames raw.instances);
  duplicateNetworkIds = duplicates (
    lib.mapAttrsToList (_name: instance: "${instance.network}:${toString instance.id}") instances
  );
  duplicateMacs = duplicates (lib.mapAttrsToList (_name: instance: instance.mac) instances);

  validatedInstances =
    assert lib.assertMsg (unknownAssignmentHosts == [ ])
      "compute assignments reference unknown hosts: ${lib.concatStringsSep ", " unknownAssignmentHosts}";
    assert lib.assertMsg (unknownAssignedInstances == [ ])
      "compute assignments reference unknown instances: ${lib.concatStringsSep ", " unknownAssignedInstances}";
    assert lib.assertMsg (
      duplicateAssignments == [ ]
    ) "compute instances assigned to multiple hosts: ${lib.concatStringsSep ", " duplicateAssignments}";
    assert lib.assertMsg (instancesWithoutClanMachine == [ ])
      "compute instances missing explicit Clan machines: ${lib.concatStringsSep ", " instancesWithoutClanMachine}";
    assert lib.assertMsg (instancesWithoutMachineConfig == [ ])
      "compute instances missing machines/<name>/configuration.nix: ${lib.concatStringsSep ", " instancesWithoutMachineConfig}";
    assert lib.assertMsg (duplicateNetworkIds == [ ])
      "compute instances have duplicate network/id pairs: ${lib.concatStringsSep ", " duplicateNetworkIds}";
    assert lib.assertMsg (
      duplicateMacs == [ ]
    ) "compute instances have duplicate MACs: ${lib.concatStringsSep ", " duplicateMacs}";
    instances;
in
{
  options.flake.compute = lib.mkOption { default = { }; };

  config.flake.compute = raw // {
    instances = validatedInstances;
  };
}

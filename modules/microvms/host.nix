{
  config,
  inputs,
  lib,
  self,
  ...
}:
let
  hostName = config.clan.core.settings.machine.name or config.networking.hostName;
  assignedInstanceNames = self.compute.assignments.${hostName} or [ ];
  assignedInstances = lib.genAttrs assignedInstanceNames (
    name:
    self.compute.instances.${name}
      or (throw "Unknown compute instance assignment ${name} on ${hostName}")
  );

  seedSecretName = name: "microcompute-age-key-${name}";
  seedAgeKeyInstances = lib.filterAttrs (
    _name: instance:
    (instance.bootstrap.transport or "none") == "seed-disk"
    && (instance.bootstrap.material or "none") == "age-key-file"
  ) assignedInstances;
in
{
  imports = [ inputs.microcompute.nixosModules.host ];

  sops.secrets = lib.mapAttrs' (
    name: _instance:
    lib.nameValuePair (seedSecretName name) {
      sopsFile = config.clan.core.settings.directory + "/sops/secrets/${name}-age.key/secret";
      format = "json";
      key = "data";
      mode = "0400";
    }
  ) seedAgeKeyInstances;

  microcompute.host = {
    name = hostName;
    ageKeyFiles = lib.mapAttrs' (
      name: _instance: lib.nameValuePair name config.sops.secrets.${seedSecretName name}.path
    ) seedAgeKeyInstances;
  };
}

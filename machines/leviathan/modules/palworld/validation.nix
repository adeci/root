{
  lib,
  instances,
  enabledInstances,
}:
let
  instanceNames = lib.attrNames instances;
  enabledInstanceNames = lib.attrNames enabledInstances;

  portAssignments = lib.concatMap (name: [
    {
      inherit name;
      kind = "game";
      inherit (enabledInstances.${name}) port;
    }
    {
      inherit name;
      kind = "query";
      port = enabledInstances.${name}.queryPort;
    }
  ]) enabledInstanceNames;

  ports = map (assignment: assignment.port) portAssignments;
  uniquePorts = lib.unique ports;

  validInstanceName = name: builtins.match "[A-Za-z0-9_-]+" name != null;
  validPort = port: builtins.isInt port && port >= 1 && port <= 65535;
  validPublicAddress = value: value == null || (builtins.isString value && value != "");
  validServerName = value: value == null || (builtins.isString value && value != "");
  validScalar =
    value:
    lib.isBool value || builtins.isInt value || builtins.isFloat value || builtins.isString value;
  validListItem =
    value:
    lib.isBool value
    || builtins.isInt value
    || builtins.isFloat value
    || (builtins.isString value && builtins.match "[A-Za-z0-9_.:-]+" value != null);
  validSetting = value: validScalar value || (builtins.isList value && lib.all validListItem value);

  invalidFlags = lib.filterAttrs (
    _: instance:
    !(lib.isBool instance.enable && lib.isBool instance.community && lib.isBool instance.openFirewall)
  ) instances;

  missingPublicAddress = lib.filterAttrs (
    _: instance: instance.community && instance.publicAddress == null
  ) instances;

  invalidPublicAddresses = lib.filterAttrs (
    _: instance: !(validPublicAddress instance.publicAddress)
  ) instances;

  invalidPublicPorts = lib.filterAttrs (
    _: instance: !(instance.publicPort == null || validPort instance.publicPort)
  ) instances;

  invalidServerNames = lib.filterAttrs (
    _: instance: !(validServerName instance.serverName)
  ) instances;

  invalidSettings = lib.concatMapAttrs (
    name: instance:
    lib.mapAttrs' (settingName: _: lib.nameValuePair "${name}.${settingName}" true) (
      lib.filterAttrs (_: value: !validSetting value) instance.settings
    )
  ) instances;

  managedSettings = lib.concatMapAttrs (
    name: instance:
    lib.mapAttrs' (settingName: _: lib.nameValuePair "${name}.${settingName}" true) (
      lib.filterAttrs (
        settingName: _:
        lib.elem settingName [
          "AdminPassword"
          "ServerPassword"
          "ServerName"
          "PublicIP"
          "PublicPort"
        ]
      ) instance.settings
    )
  ) instances;

  renderPorts = lib.concatMapStringsSep ", " (
    assignment: "${assignment.name}/${assignment.kind}:${toString assignment.port}"
  );
in
[
  {
    assertion = lib.all validInstanceName instanceNames;
    message = "Palworld instance names may only contain letters, numbers, underscores, and hyphens: ${lib.concatStringsSep ", " instanceNames}";
  }
  {
    assertion = lib.all validPort ports;
    message = "Palworld ports must be integers from 1 to 65535: ${renderPorts portAssignments}";
  }
  {
    assertion = builtins.length ports == builtins.length uniquePorts;
    message = "Palworld instances must use unique UDP ports: ${renderPorts portAssignments}";
  }
  {
    assertion = missingPublicAddress == { };
    message = "Palworld community instances need publicAddress: ${lib.concatStringsSep ", " (lib.attrNames missingPublicAddress)}";
  }
  {
    assertion = invalidPublicAddresses == { };
    message = "Palworld publicAddress values must be null or non-empty strings: ${lib.concatStringsSep ", " (lib.attrNames invalidPublicAddresses)}";
  }
  {
    assertion = invalidPublicPorts == { };
    message = "Palworld publicPort values must be null or integers from 1 to 65535: ${lib.concatStringsSep ", " (lib.attrNames invalidPublicPorts)}";
  }
  {
    assertion = invalidServerNames == { };
    message = "Palworld serverName values must be null or non-empty strings: ${lib.concatStringsSep ", " (lib.attrNames invalidServerNames)}";
  }
  {
    assertion = invalidFlags == { };
    message = "Palworld enable, community, and openFirewall values must be booleans: ${lib.concatStringsSep ", " (lib.attrNames invalidFlags)}";
  }
  {
    assertion = lib.all (name: lib.all builtins.isString instances.${name}.extraArgs) instanceNames;
    message = "Palworld extraArgs values must be strings.";
  }
  {
    assertion = invalidSettings == { };
    message = "Palworld settings only support bools, ints, floats, strings, and lists of bools, numbers, or safe enum strings: ${lib.concatStringsSep ", " (lib.attrNames invalidSettings)}";
  }
  {
    assertion = managedSettings == { };
    message = "Palworld managed settings must use top-level options or clan vars, not settings: ${lib.concatStringsSep ", " (lib.attrNames managedSettings)}";
  }
]

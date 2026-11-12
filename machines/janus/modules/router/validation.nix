{ lib, self, ... }:
let
  topology = import ./topology.nix { inherit lib self; };

  inherit (topology) homelan;
  devices = homelan.hosts;
  dnsDevices = lib.filterAttrs (_: host: host.publishDns or true) devices;

  countMatching = pred: values: builtins.length (builtins.filter pred values);
  duplicates =
    values:
    lib.filter (value: countMatching (candidate: candidate == value) values > 1) (lib.unique values);

  allAliases = lib.concatMap (host: host.aliases or [ ]) (lib.attrValues dnsDevices);
  aliasHostConflicts = lib.intersectLists allAliases (lib.attrNames devices);
  duplicateAliases = duplicates allAliases;
in
{
  assertions = [
    {
      assertion = duplicateAliases == [ ];
      message = "homelan aliases must be unique: ${lib.concatStringsSep ", " duplicateAliases}";
    }
    {
      assertion = aliasHostConflicts == [ ];
      message = "homelan aliases conflict with host names: ${lib.concatStringsSep ", " aliasHostConflicts}";
    }
  ];
}

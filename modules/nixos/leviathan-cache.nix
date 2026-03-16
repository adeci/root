{
  lib,
  self,
  ...
}:
let
  harmoniaKeyPath = self + "/vars/shared/harmonia-signing-key/signing-key.pub/value";
  hasHarmonia = builtins.pathExists harmoniaKeyPath;
in
{
  nix.settings = lib.mkIf hasHarmonia {
    extra-substituters = [ "http://leviathan.cymric-daggertooth.ts.net:5000?priority=41" ];
    extra-trusted-public-keys = [
      (lib.strings.trim (builtins.readFile harmoniaKeyPath))
    ];
  };
}

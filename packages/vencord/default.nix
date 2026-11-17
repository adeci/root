{
  applyPatches,
  inputs,
  lib,
  vencord,
}:
let
  plugins = import ./plugins.nix { inherit inputs applyPatches; };
in
vencord.overrideAttrs (old: {
  # Vencord compiles desktop userplugins and their native helpers together.
  preBuild =
    (old.preBuild or "")
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: source: ''
        mkdir -p ${lib.escapeShellArg "src/userplugins/${name}"}
        cp -R ${lib.escapeShellArg "${source}/."} ${lib.escapeShellArg "src/userplugins/${name}/"}
      '') plugins
    );
  meta = old.meta // {
    platforms = [ "x86_64-linux" ];
  };
})

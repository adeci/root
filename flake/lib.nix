{ lib }:
{
  # `<name>.nix` files and `<name>/default.nix` folders by name; lib.nix holds helpers.
  nixEntries =
    dir:
    lib.mapAttrs' (entry: _: lib.nameValuePair (lib.removeSuffix ".nix" entry) (dir + "/${entry}")) (
      lib.filterAttrs (
        entry: type:
        entry != "lib.nix"
        && (
          (type == "regular" && lib.hasSuffix ".nix" entry)
          || (type == "directory" && builtins.pathExists (dir + "/${entry}/default.nix"))
        )
      ) (builtins.readDir dir)
    );

  # Packages that fail to evaluate count as unavailable.
  availablePackages =
    platform:
    lib.filterAttrs (
      _: package:
      let
        result = builtins.tryEval (lib.meta.availableOn platform package);
      in
      result.success && result.value
    );
}

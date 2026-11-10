{ inputs, lib, ... }:
let
  featureDirs =
    dir:
    builtins.attrNames (
      lib.filterAttrs (
        name: type: type == "directory" && builtins.pathExists (dir + "/${name}/default.nix")
      ) (builtins.readDir dir)
    );

  # Heavy GUI builds, not worth routine checks.
  skipChecks = [
    "element-desktop"
    "emacs"
    "handy"
    "karabiner-elements"
    "prusa-slicer"
    "signal-desktop"
    "vencord"
    "vesktop"
    "zipline"
  ];
in
{
  imports = [ inputs.wrapper-modules.flakeModules.wrappers ];

  flake.wrappers = lib.genAttrs (featureDirs ../wrappers) (name: {
    imports = [ (../wrappers + "/${name}") ];
    _module.args = {
      inherit inputs;
      inherit (inputs) self;
    };
  });

  perSystem =
    {
      config,
      pkgs,
      system,
      self',
      inputs',
      ...
    }:
    let
      # Packages that can't even evaluate here (niri on darwin) count as unavailable.
      availableHere = lib.filterAttrs (
        _: drv:
        let
          r = builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform drv);
        in
        r.success && r.value
      );

      build =
        name:
        let
          result = pkgs.callPackage (../packages + "/${name}") {
            inherit
              inputs
              inputs'
              lib
              self'
              pkgs
              ;
            inherit (inputs) self;
          };
        in
        if lib.isDerivation result then
          { ${name} = result; }
        else
          lib.mapAttrs' (key: lib.nameValuePair "${name}-${key}") (
            lib.filterAttrs (_: lib.isDerivation) result
          );

      packages = availableHere (lib.mergeAttrsList (map build (featureDirs ../packages)));

      wrappers = availableHere (
        lib.genAttrs (featureDirs ../wrappers) (name: inputs.self.wrappers.${name}.wrap { inherit pkgs; })
      );
    in
    {
      # Machines use this instance too (flake/clan.nix).
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      inherit packages;

      wrappers.control_type = "build";
      wrappers.packages = lib.mapAttrs (_: _: true) wrappers;

      checks = lib.mapAttrs' (name: lib.nameValuePair "package-${name}") (
        removeAttrs (
          packages // lib.genAttrs (builtins.attrNames wrappers) (name: config.packages.${name})
        ) skipChecks
      );
    };
}

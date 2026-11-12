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
    "emacs"
    "karabiner-elements"
    "prusa-slicer"
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
      # Packages that can't even evaluate on this platform count as unavailable.
      availableHere = lib.filterAttrs (
        _: drv:
        let
          r = builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform drv);
        in
        r.success && r.value
      );

      packages = availableHere (
        lib.genAttrs (featureDirs ../packages) (
          name:
          pkgs.callPackage (../packages + "/${name}") {
            inherit
              inputs
              inputs'
              lib
              self'
              pkgs
              ;
            inherit (inputs) self;
          }
        )
      );

      wrappers = availableHere (
        lib.genAttrs (featureDirs ../wrappers) (name: inputs.self.wrappers.${name}.wrap { inherit pkgs; })
      );
    in
    {
      # Machines use this instance too.
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

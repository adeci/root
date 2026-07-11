# Package layer: interpret packages/default.nix registry as flake outputs.
# Normal packages are called directly; wrapper packages use nix-wrapper-modules.
{
  inputs,
  lib,
  flake-parts-lib,
  ...
}:
let
  registry = import ../../packages;

  defaultPolicy = {
    systems = null;
    checks = true;
  };

  allowedTopLevelKeys = [
    "packages"
    "wrappers"
  ];

  allowedEntryKeys = [
    "path"
    "systems"
    "checks"
  ];

  validateTopLevel =
    if !(builtins.isAttrs registry) || builtins.isFunction registry then
      throw "packages/default.nix must return a registry attrset"
    else
      let
        unknownKeys = lib.subtractLists allowedTopLevelKeys (builtins.attrNames registry);
      in
      if unknownKeys != [ ] then
        throw "packages/default.nix: unknown top-level keys: ${lib.concatStringsSep ", " unknownKeys}"
      else if !(builtins.isAttrs (registry.packages or { })) then
        throw "packages/default.nix: `packages` must be an attrset"
      else if !(builtins.isAttrs (registry.wrappers or { })) then
        throw "packages/default.nix: `wrappers` must be an attrset"
      else
        registry;

  validateEntry =
    kind: name: entry:
    let
      unknownKeys = lib.subtractLists allowedEntryKeys (builtins.attrNames entry);
      policy =
        defaultPolicy
        // lib.optionalAttrs (entry ? systems) { inherit (entry) systems; }
        // lib.optionalAttrs (entry ? checks) { inherit (entry) checks; };
      invalidSystems = lib.optionals (policy.systems != null) (
        lib.filter (
          system: !(builtins.isString system && builtins.elem system lib.platforms.all)
        ) policy.systems
      );
      label = "packages.${kind}.${name}";
    in
    if !(builtins.isAttrs entry) || builtins.isFunction entry then
      throw "${label}: registry entry must be an attrset"
    else if unknownKeys != [ ] then
      throw "${label}: unknown keys: ${lib.concatStringsSep ", " unknownKeys}"
    else if !(entry ? path) then
      throw "${label}: missing `path`"
    else if !(builtins.isPath entry.path) then
      throw "${label}: `path` must be a path"
    else if !(policy.systems == null || builtins.isList policy.systems) then
      throw "${label}: `systems` must be null or a list of system strings"
    else if invalidSystems != [ ] then
      throw "${label}: invalid systems: ${lib.concatStringsSep ", " invalidSystems}"
    else if !(builtins.isBool policy.checks) then
      throw "${label}: `checks` must be a boolean"
    else
      entry
      // {
        inherit kind name;
        inherit (policy) systems checks;
      };

  validatedRegistry = validateTopLevel;
  packageEntries = lib.mapAttrs (validateEntry "packages") (validatedRegistry.packages or { });
  wrapperEntries = lib.mapAttrs (validateEntry "wrappers") (validatedRegistry.wrappers or { });
  duplicateNames = lib.intersectLists (builtins.attrNames packageEntries) (
    builtins.attrNames wrapperEntries
  );
  entries =
    if duplicateNames == [ ] then
      packageEntries // wrapperEntries
    else
      throw "packages/default.nix: names cannot appear in both `packages` and `wrappers`: ${lib.concatStringsSep ", " duplicateNames}";

  supportsSystem = system: entry: entry.systems == null || builtins.elem system entry.systems;
  entriesFor = system: lib.filterAttrs (_: entry: supportsSystem system entry) entries;

  packageEntriesFor =
    system: lib.filterAttrs (_: entry: entry.kind == "packages") (entriesFor system);
  wrapperEntriesFor =
    system: lib.filterAttrs (_: entry: entry.kind == "wrappers") (entriesFor system);
in
{
  imports = [ inputs.wrapper-modules.flakeModules.wrappers ];

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { lib, ... }:
    {
      options.adeci.packageLayer = {
        managedNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Package names owned by packages/ registry.";
        };

        checkPackages = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.raw;
          default = { };
          description = "Registry packages that should be included in flake checks.";
        };
      };
    }
  );

  config = {
    flake.wrappers = lib.mapAttrs (_: entry: {
      imports = [ entry.path ];
      _module.args = {
        inherit inputs;
        inherit (inputs) self;
      };
    }) wrapperEntries;

    perSystem =
      {
        config,
        system,
        self',
        inputs',
        ...
      }:
      let
        selectedEntries = entriesFor system;
        selectedPackageEntries = packageEntriesFor system;
        selectedWrapperEntries = wrapperEntriesFor system;

        packagePkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        callPackage =
          _name: entry:
          packagePkgs.callPackage entry.path {
            inherit
              inputs
              inputs'
              lib
              self'
              ;
            pkgs = packagePkgs;
            inherit (inputs) self;
          };

        packages = lib.mapAttrs callPackage selectedPackageEntries;

        checkNames = lib.filter (name: selectedEntries.${name}.checks) (builtins.attrNames selectedEntries);
      in
      {
        wrappers.control_type = "build";
        wrappers.pkgs = packagePkgs;
        wrappers.packages = lib.mapAttrs (_: _: true) selectedWrapperEntries;

        inherit packages;

        adeci.packageLayer = {
          managedNames = builtins.attrNames entries;
          checkPackages = lib.genAttrs checkNames (name: config.packages.${name});
        };
      };
  };
}

{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  freeform = types.attrsOf types.anything;

  # Runs a clan vars generator from the modules.
  generate =
    name: generator:
    pkgs.runCommand "vars-${name}" { nativeBuildInputs = generator.runtimeInputs or [ ]; } ''
      set -euo pipefail
      mkdir -p "$out"
      ${generator.script}
    '';
in
{
  # Clan's real state and backup options: they turn each state's scripts into the commands clan and backup providers run.
  imports = [ "${inputs.clan-core}/nixosModules/clanCore/backups.nix" ];

  # Stands in for the rest of clan: accepts the modules' clan settings and points each vars file at its generator's output.
  options.clan.core = {
    settings.machine.name = mkOption {
      type = types.str;
      default = config.networking.hostName;
    };
    postgresql = mkOption { type = freeform; };
    vars.generators = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          let
            generated = generate name config;
          in
          {
            freeformType = freeform;
            options.files = mkOption {
              type = types.attrsOf (
                types.submodule (
                  { name, ... }:
                  {
                    freeformType = freeform;
                    options.path = mkOption {
                      type = types.str;
                      default = "${generated}/${name}";
                    };
                  }
                )
              );
            };
          }
        )
      );
    };
  };
}

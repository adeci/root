# Builds a Terraform workspace and its tofu apps.
{
  inputs,
  lib,
  pkgs,
  self',
}:
{
  name,
  stateKey,
  modules,
  appPrefix,
  commands,
  scripts ? { },
}:
let
  configFile = inputs.terranix.lib.terranixConfiguration {
    inherit pkgs;
    modules = [
      ../../terranix/base
      { terraform.backend.s3.key = stateKey; }
    ]
    ++ modules;
    extraArgs = {
      inherit (inputs) self;
      inherit self';
    };
  };

  # Runs `text` in .terraform/<name>, with the config installed and the state bucket's credentials exported.
  app = command: text: {
    program = pkgs.writeShellApplication {
      name = "${appPrefix}-${command}";
      runtimeInputs = [
        pkgs.gitMinimal
        pkgs.opentofu
        self'.packages.clan-cli
      ];
      runtimeEnv = {
        WORKSPACE = name;
        WORKSPACE_CONFIG = "${configFile}";
      };
      text = builtins.readFile ./tofu-workspace.sh + text;
    };
  };
in
lib.mapAttrs' (command: text: lib.nameValuePair "${appPrefix}-${command}" (app command text)) (
  lib.genAttrs commands (command: ''tofu ${command} "$@"'')
  // lib.mapAttrs (_: builtins.readFile) scripts
)

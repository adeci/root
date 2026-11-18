# Builds a Terraform workspace, its tofu apps with the providers Nix builds, and a check that its config validates against them.
{
  inputs,
  lib,
  pkgs,
}:
{
  name,
  stateKey,
  providers,
  modules,
  appPrefix,
  commands,
  scripts ? { },
}:
let
  # Each provider's package by the name the config calls it; the base module's own is `external`, which reads clan secrets.
  allProviders = providers // {
    external = pkgs.terraform-providers.hashicorp_external;
  };

  # init installs providers from these builds alone, never from a registry.
  tofu = pkgs.opentofu.withPlugins (_: lib.attrValues allProviders);

  clan-cli = inputs.clan-core.packages.${pkgs.stdenv.hostPlatform.system}.clan-cli;

  configFile = inputs.terranix.lib.terranixConfiguration {
    inherit pkgs;
    modules = [
      ../../terranix/base
      {
        terraform.backend.s3.key = stateKey;
        terraform.required_providers = lib.mapAttrs (_: provider: {
          source = lib.removePrefix "registry.terraform.io/" provider.provider-source-address;
          inherit (provider) version;
        }) allProviders;
      }
    ]
    ++ modules;
    extraArgs = {
      inherit (inputs) self;
      inherit clan-cli;
    };
  };

  # Runs `text` in .terraform/<name>, with the config installed and the state bucket's credentials exported.
  app = command: text: {
    program = pkgs.writeShellApplication {
      name = "${appPrefix}-${command}";
      runtimeInputs = [
        pkgs.gitMinimal
        tofu
        clan-cli
      ];
      runtimeEnv = {
        WORKSPACE = name;
        WORKSPACE_CONFIG = "${configFile}";
        COMMAND = command;
      };
      text = builtins.readFile ./tofu-workspace.sh + text;
    };
  };
in
{
  apps =
    lib.mapAttrs' (command: text: lib.nameValuePair "${appPrefix}-${command}" (app command text))
      (
        lib.genAttrs commands (command: ''tofu ${command} "$@"'')
        // lib.mapAttrs (_: builtins.readFile) scripts
      );

  # Built in the sandbox, where init has only the providers above; the result is the config once it validates against their schemas.
  checks."tofu-${name}" = pkgs.runCommand "tofu-${name}" { nativeBuildInputs = [ tofu ]; } ''
    cp ${configFile} config.tf.json
    tofu init -backend=false
    tofu validate
    ln -s ${configFile} $out
  '';
}

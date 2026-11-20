# Builds a Terraform workspace, its tofu apps with the providers Nix builds, and a check that its config validates against them.
{
  inputs,
  lib,
  pkgs,
  self',
}:
{
  name,
  stateKey,
  providers,
  modules,
  extraArgs ? { },
  appPrefix,
  commands,
  scripts ? { },
  # Packages the scripts need besides tofu, git and clan, such as jq.
  runtimeInputs ? [ ],
  # { host, forwards }: the commands that reach the providers' endpoints do so through one ssh connection to host, each forward <local port>:<address>:<port> listening on 127.0.0.1.
  tunnel ? null,
  # <device> = <provider configuration>, such as nexus = "routeros.nexus": `apply <device>` applies only that configuration's resources, so the others' endpoints may be unreachable.
  applyAlone ? { },
  # A program that apply runs in place of `tofu apply`, inside the tunnel, with the arguments tofu apply would get; it finds tofu and clan on the app's PATH.
  apply ? null,
}:
let
  # Each provider's package by the name the config calls it; the base module's own is `external`, which reads clan secrets.
  allProviders = providers // {
    external = pkgs.terraform-providers.hashicorp_external;
  };

  # init installs providers from these builds alone, never from a registry.
  tofu = pkgs.opentofu.withPlugins (_: lib.attrValues allProviders);

  clan-cli = self'.packages.clan-cli;

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
    }
    // extraArgs;
  };

  # The tofu commands that reach the providers' endpoints.
  reachesProviders = [
    "plan"
    "apply"
    "destroy"
  ];

  # The addresses of the resources a provider configuration manages, for -target-file, which targets everything when empty.
  targetFile =
    provider:
    let
      addresses = lib.concatLists (
        lib.mapAttrsToList (
          type: resources:
          lib.mapAttrsToList (resource: _: "${type}.${resource}") (
            lib.filterAttrs (_: settings: settings.provider or null == provider) resources
          )
        ) configFile.config.resource
      );
    in
    assert lib.assertMsg (addresses != [ ]) "the ${name} config has no resources of ${provider}";
    pkgs.writeText "${name}-${provider}-resources" (lib.concatLines addresses);

  # Runs `text` in .terraform/<name>, with the config installed and the state bucket's credentials exported.
  app = command: text: {
    program = pkgs.writeShellApplication {
      name = "${appPrefix}-${command}";
      runtimeInputs = [
        pkgs.gitMinimal
        tofu
        clan-cli
      ]
      ++ runtimeInputs;
      runtimeEnv = {
        WORKSPACE = name;
        WORKSPACE_CONFIG = "${configFile}";
        COMMAND = command;
      };
      text = builtins.readFile ./tofu-workspace.sh + text;
    };
  };

  # Runs its arguments while the tunnel is open.
  tunnelProgram = pkgs.writeShellApplication {
    name = "${appPrefix}-tunnel";
    runtimeInputs = [ pkgs.openssh ];
    runtimeEnv = {
      TUNNEL_HOST = tunnel.host;
      TUNNEL_FORWARDS = toString tunnel.forwards;
    };
    text = builtins.readFile ./tunnel.sh;
  };

  applyCommand = if apply == null then "tofu apply" else lib.getExe apply;

  # `command` with the app's arguments, inside the tunnel when the workspace has one.
  throughTunnel =
    command: lib.optionalString (tunnel != null) "${lib.getExe tunnelProgram} " + ''${command} "$@"'';

  # Each applyAlone device's resource list, for -target-file.
  aloneTargets = pkgs.writeText "${name}-apply-alone.json" (
    builtins.toJSON (lib.mapAttrs (_: targetFile) applyAlone)
  );
in
{
  apps =
    lib.mapAttrs' (command: text: lib.nameValuePair "${appPrefix}-${command}" (app command text)) (
      lib.genAttrs commands (
        command:
        if command == "apply" then
          throughTunnel applyCommand
        else if lib.elem command reachesProviders then
          throughTunnel "tofu ${command}"
        else
          ''tofu ${command} "$@"''
      )
      // lib.mapAttrs (_: builtins.readFile) scripts
    )
    # In front of that apply: a first argument naming a device is checked before anything runs.
    // lib.optionalAttrs (applyAlone != { }) {
      "${appPrefix}-apply".program = pkgs.writeShellApplication {
        name = "${appPrefix}-apply";
        runtimeInputs = [ pkgs.jq ];
        runtimeEnv = {
          APPLY = lib.getExe (app "apply" (throughTunnel applyCommand)).program;
          TARGETS = aloneTargets;
        };
        text = builtins.readFile ./apply-alone.sh;
      };
    };

  # Built in the sandbox, where init has only the providers above; the result is the config once it validates against their schemas.
  checks."tofu-${name}" = pkgs.runCommand "tofu-${name}" { nativeBuildInputs = [ tofu ]; } ''
    cp ${configFile} config.tf.json
    tofu init -backend=false
    tofu validate
    ln -s ${configFile} $out
  '';
}

{
  config,
  lib,
  ...
}:
let
  inherit (config.flake.inventory) appliances router;
  inherit (config.flake.inventory.routeros) admin models;
in
{
  perSystem =
    { pkgs, self', ... }:
    let
      netinstall = self'.packages.routeros-netinstall;

      # Reinstalls an appliance with its model's packages, leaving a DHCP client on each port it is managed through; the management port's sends the appliance's name.
      netinstallProgram =
        name: appliance:
        let
          model = models.${appliance.model};
          packages = [ "routeros" ] ++ model.extraPackages or [ ];
          flags = [
            "--device ${name}"
            "--model ${lib.escapeShellArg appliance.model}"
            "--arch ${model.arch}"
          ]
          ++ map (package: "--package ${package} ${netinstall.npk model.arch package}") packages
          ++ [
            "--management-port ${appliance.managementPort}"
            "--client-id ${appliance.lan.clientId}"
          ]
          ++ lib.optional (
            appliance.fallbackPort != appliance.managementPort
          ) "--fallback-port ${appliance.fallbackPort}"
          # Process substitution keeps the password off argv and out of any file of our own.
          ++ [
            "--admin-user ${lib.escapeShellArg admin.user}"
            "--admin-password-file <(clan secrets get ${lib.escapeShellArg admin.secret})"
          ];
        in
        pkgs.writeShellApplication {
          name = "netinstall-${name}";
          runtimeInputs = [ self'.packages.clan-cli ];
          text = "exec ${lib.getExe netinstall} \\\n  ${lib.concatStringsSep " \\\n  " flags}\n";
        };

      # Each appliance's reinstall and the API the router reaches it on, by name.
      devices = pkgs.writeText "net-rebuild-devices.json" (
        builtins.toJSON (
          lib.mapAttrs (name: appliance: {
            netinstall = lib.getExe (netinstallProgram name appliance);
            apiAddress = appliance.api.address;
            apiPort = appliance.api.port;
          }) appliances
        )
      );
    in
    {
      # Reinstalls an appliance, forgets its old resources in the Terraform state and applies its configuration once the router reaches it.
      apps = lib.optionalAttrs (self'.packages ? routeros-netinstall) {
        net-rebuild.program = pkgs.writeShellApplication {
          name = "net-rebuild";
          runtimeInputs = [
            pkgs.jq
            pkgs.openssh
          ];
          runtimeEnv = {
            DEVICES = devices;
            STATE = self'.apps.net-state.program;
            STATE_RM_DEVICE = self'.apps.net-state-rm-device.program;
            APPLY = self'.apps.net-apply.program;
            ROUTER = router.machine;
            ROUTER_HOST = config.flake.clan.inventory.machines.${router.machine}.deploy.targetHost;
          };
          text = builtins.readFile ./net-rebuild.sh;
        };
      };
    };
}

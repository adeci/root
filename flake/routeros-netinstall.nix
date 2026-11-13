{ config, lib, ... }:
let
  inherit (config.flake.inventory) appliances;
  inherit (config.flake.inventory.routeros) admin models;
in
{
  perSystem =
    { pkgs, self', ... }:
    let
      netinstall = self'.packages.routeros-netinstall;

      # Reinstalls an appliance with its model's packages, leaving a DHCP client on each port it is managed through.
      app =
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
          ++ map (port: "--dhcp-client ${port}") (
            lib.unique [
              appliance.managementPort
              appliance.fallbackPort
            ]
          )
          # Process substitution keeps the password off argv and out of any file of our own.
          ++ [
            "--admin-user ${lib.escapeShellArg admin.user}"
            "--admin-password-file <(clan secrets get ${lib.escapeShellArg admin.secret})"
            ''"$@"''
          ];
        in
        {
          program = pkgs.writeShellApplication {
            name = "net-netinstall-${name}";
            runtimeInputs = [ self'.packages.clan-cli ];
            text = "exec ${lib.getExe netinstall} \\\n  ${lib.concatStringsSep " \\\n  " flags}\n";
          };
        };
    in
    {
      apps = lib.optionalAttrs (self'.packages ? routeros-netinstall) (
        lib.mapAttrs' (
          name: appliance: lib.nameValuePair "net-netinstall-${name}" (app name appliance)
        ) appliances
      );
    };
}

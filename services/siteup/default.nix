{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    ;
  inherit (lib.types)
    str
    port
    attrsOf
    listOf
    anything
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "@onix/siteup";
    description = "Deploy flake-based web applications with secrets management";
    categories = [ "Web" ];
    readme = builtins.readFile ./README.md;
  };

  roles = {
    app = {
      description = "Run a web application from a flake input";
      interface = {
        options = {
          name = mkOption {
            type = str;
            description = "Unique name for this site instance (used for systemd service, working directory, etc.)";
          };

          flakeRef = mkOption {
            type = str;
            description = "Name of the flake input to use (must match an input in your flake.nix)";
          };

          package = mkOption {
            type = str;
            default = "default";
            description = "Package attribute to run (e.g., 'default' for packages.*.default)";
          };

          port = mkOption {
            type = lib.types.nullOr port;
            default = null;
            description = "Port the application listens on (sets PORT env var). Optional if using args instead.";
          };

          host = mkOption {
            type = str;
            default = "127.0.0.1";
            description = "Host to bind to (sets HOST env var, defaults to localhost for tunnel use)";
          };

          env = mkOption {
            type = attrsOf anything;
            default = { };
            description = "Non-secret environment variables to pass to the application";
          };

          secrets = mkOption {
            type = listOf str;
            default = [ ];
            description = "List of secret environment variable names to prompt for via clan vars";
          };

          args = mkOption {
            type = listOf str;
            default = [ ];
            description = "Command line arguments to pass to the application binary";
            example = [
              "--port"
              "4444"
              "--host"
              "0.0.0.0"
            ];
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              inputs,
              lib,
              ...
            }:
            let
              inherit (settings)
                name
                flakeRef
                package
                port
                host
                env
                secrets
                args
                ;

              # Working directory for this site
              workDir = "/var/lib/siteup/${name}";

              # Get the package from the flake input
              sitePackage = inputs.${flakeRef}.packages.${pkgs.stdenv.hostPlatform.system}.${package};

              # Environment file path for secrets
              envFile = config.clan.core.vars.generators."siteup-${name}".files."${name}.env".path;

              # Combined environment variables
              environment =
                (lib.optionalAttrs (port != null) { PORT = toString port; }) // { HOST = host; } // env;

              hasSecrets = secrets != [ ];
            in
            {
              # Create dedicated user and group
              users.users."siteup-${name}" = {
                isSystemUser = true;
                group = "siteup-${name}";
                home = workDir;
                createHome = true;
              };
              users.groups."siteup-${name}" = { };

              # Systemd service for the site
              systemd.services."siteup-${name}" = {
                description = "Siteup: ${name}";
                after = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];

                inherit environment;

                serviceConfig = {
                  Type = "simple";
                  User = "siteup-${name}";
                  Group = "siteup-${name}";
                  WorkingDirectory = workDir;
                  StateDirectory = "siteup/${name}";
                  ExecStart =
                    let
                      bin = "${sitePackage}/bin/${sitePackage.pname or sitePackage.name or name}";
                      argsStr = lib.escapeShellArgs args;
                    in
                    if args == [ ] then bin else "${bin} ${argsStr}";
                  Restart = "on-failure";
                  RestartSec = "5s";

                  # Load secrets from env file if we have any
                  EnvironmentFile = mkIf hasSecrets [ envFile ];
                };
              };

              # Secrets generator (only if secrets are defined)
              clan.core.vars.generators."siteup-${name}" = mkIf hasSecrets {
                share = true;
                files."${name}.env" = { };

                prompts = builtins.listToAttrs (
                  map (secretName: {
                    name = secretName;
                    value = {
                      description = "Secret '${secretName}' for site '${name}'";
                      type = "hidden";
                      persist = true;
                    };
                  }) secrets
                );

                runtimeInputs = [ pkgs.coreutils ];

                script =
                  let
                    writeSecret = secretName: ''
                      echo "${secretName}='$(cat "$prompts/${secretName}" | tr -d '\n')'" >> "$out/${name}.env"
                    '';
                  in
                  ''
                    # Generate env file with all secrets
                    ${lib.concatMapStrings writeSecret secrets}
                  '';
              };
            };
        };
    };
  };
}

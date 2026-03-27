_: {
  _class = "clan.service";

  manifest = {
    name = "@adeci/security-keys";
    description = "Deploy FIDO2 SSH key handles to machines";
    categories = [ "Security" ];
    readme = builtins.readFile ./README.md;
  };

  roles.default = {
    description = "Receives FIDO2 SSH key handles and deploys them to ~/.ssh/";

    interface =
      { lib, ... }:
      {
        options.keys = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Name of the FIDO2 security key (e.g. spark, ember, vault)";
                  example = "spark";
                };
                owner = lib.mkOption {
                  type = lib.types.str;
                  description = "Username who owns this key";
                  example = "alex";
                };
              };
            }
          );
          description = "List of YubiKey FIDO2 keys to deploy handles for";
        };
      };

    perInstance =
      { settings, instanceName, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            generatorName = instanceName;
            keyNames = map (k: k.name) settings.keys;
          in
          {
            # Generate clan vars for each key handle
            clan.core.vars.generators."${generatorName}" = {
              share = true;
              files = lib.listToAttrs (
                map (name: {
                  inherit name;
                  value = {
                    secret = true;
                  };
                }) keyNames
              );
              runtimeInputs = [ pkgs.coreutils ];

              prompts = lib.listToAttrs (
                map (name: {
                  inherit name;
                  value = {
                    description = "FIDO2 SSH key handle for '${name}' (paste contents of id_ed25519_sk_${name})";
                    type = "multiline-hidden";
                    persist = true;
                  };
                }) keyNames
              );

              script = lib.concatMapStringsSep "\n" (name: ''
                cp "$prompts"/${name} "$out"/${name}
              '') keyNames;
            };

            # Deploy key handles to each owner's ~/.ssh/
            system.activationScripts."deploy-security-keys-${instanceName}" = lib.concatMapStringsSep "\n" (
              key:
              let
                handlePath = config.clan.core.vars.generators."${generatorName}".files.${key.name}.path;
                user = key.owner;
                homeDir = config.users.users.${user}.home;
              in
              ''
                install -d -m 700 -o ${user} ${homeDir}/.ssh
                install -m 600 -o ${user} ${handlePath} ${homeDir}/.ssh/id_ed25519_sk_${key.name}
              ''
            ) settings.keys;
          };
      };
  };
}

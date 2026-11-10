_: {
  _class = "clan.service";

  manifest = {
    name = "@adeci/security-keys";
    description = "Deploy FIDO2 SSH key handles and configure SSH identity discovery";
    categories = [ "Security" ];
    readme = builtins.readFile ./README.md;
  };

  roles.default = {
    description = "Receives FIDO2 SSH key handles, deploys them to ~/.ssh/, and configures SSH to use them";

    interface =
      { lib, ... }:
      {
        options.keys = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Name of the FIDO2 security key";
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
          description = "All FIDO2 keys in the fleet (defined at role level)";
        };
        options.use = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Which keys to use on this machine (subset of key names)";
          example = [
            "spark"
          ];
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
            allKeyNames = map (k: k.name) settings.keys;
            deployKeys = builtins.filter (k: builtins.elem k.name settings.use) settings.keys;
            unknownKeys = builtins.filter (name: !builtins.elem name allKeyNames) settings.use;
          in
          {
            assertions = [
              {
                assertion = unknownKeys == [ ];
                message = "security-keys: unknown key(s) in 'use': ${lib.concatStringsSep ", " unknownKeys}. Must be defined in role-level 'keys'.";
              }
            ];
            # Shared generator — identical across all machines, stores ALL key handles
            clan.core.vars.generators.${instanceName} = {
              share = true;
              files = lib.listToAttrs (
                map (name: {
                  inherit name;
                  value.secret = true;
                }) allKeyNames
              );
              runtimeInputs = [ pkgs.coreutils ];
              prompts = lib.listToAttrs (
                map (name: {
                  inherit name;
                  value = {
                    description = "FIDO2 SSH key handle for '${name}'";
                    type = "multiline-hidden";
                    persist = true;
                  };
                }) allKeyNames
              );
              script = lib.concatMapStringsSep "\n" (name: ''cp "$prompts"/${name} "$out"/${name}'') allKeyNames;
            };

            # Deploy only this machine's keys
            system.activationScripts."deploy-fido2-handles" = lib.concatMapStringsSep "\n" (
              key:
              let
                handlePath = config.clan.core.vars.generators.${instanceName}.files.${key.name}.path;
                homeDir = config.users.users.${key.owner}.home;
              in
              ''
                install -d -m 700 -o ${key.owner} ${homeDir}/.ssh
                install -m 600 -o ${key.owner} ${handlePath} ${homeDir}/.ssh/id_ed25519_sk_${key.name}
                if [ "$(tail -c1 ${homeDir}/.ssh/id_ed25519_sk_${key.name})" != "" ]; then
                  echo >> ${homeDir}/.ssh/id_ed25519_sk_${key.name}
                fi
              ''
            ) deployKeys;

            # SSH config for this machine's keys only
            programs.ssh.extraConfig = lib.concatStringsSep "\n" (
              map (
                key: "IdentityFile ${config.users.users.${key.owner}.home}/.ssh/id_ed25519_sk_${key.name}"
              ) deployKeys
            );
          };
      };
  };
}

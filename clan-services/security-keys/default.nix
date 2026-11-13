{
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
                  example = "yubikey-a";
                };
                owner = lib.mkOption {
                  type = lib.types.str;
                  description = "Username who owns this key";
                  example = "alice";
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
            "yubikey-a"
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
            allKeyNames = map (key: key.name) settings.keys;
            deployKeys = lib.filter (key: lib.elem key.name settings.use) settings.keys;
            unknownKeys = lib.filter (name: !lib.elem name allKeyNames) settings.use;
            identityFile = key: "${config.users.users.${key.owner}.home}/.ssh/id_ed25519_sk_${key.name}";
            deployHandle = pkgs.writeShellApplication {
              name = "deploy-fido2-handle";
              runtimeInputs = [ pkgs.coreutils ];
              text = builtins.readFile ./deploy-handle.sh;
            };
          in
          {
            assertions = [
              {
                assertion = unknownKeys == [ ];
                message = "@adeci/security-keys: unknown key(s) in 'use': ${lib.concatStringsSep ", " unknownKeys}. Must be defined in role-level 'keys'.";
              }
            ];
            # Identical on every machine, so it holds all key handles.
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

            system.activationScripts."deploy-fido2-handles" = lib.concatMapStringsSep "\n" (
              key:
              lib.escapeShellArgs [
                (lib.getExe deployHandle)
                key.owner
                config.clan.core.vars.generators.${instanceName}.files.${key.name}.path
                (identityFile key)
              ]
            ) deployKeys;

            programs.ssh.extraConfig = lib.concatMapStringsSep "\n" (
              key: "IdentityFile ${identityFile key}"
            ) deployKeys;
          };
      };
  };
}

{
  # Store binaries re-signed with this Mac's own key.
  darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      binary = lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            source = lib.mkOption {
              type = lib.types.str;
              description = "The binary to sign, usually from a package.";
            };
            identifier = lib.mkOption {
              type = lib.types.str;
              example = "git.felix.borders";
              description = "Signing identifier; together with the key, it is what macOS recognises across rebuilds.";
            };
            path = lib.mkOption {
              type = lib.types.str;
              readOnly = true;
              default = "/usr/local/libexec/${name}";
              description = "The signed copy, at a path that never changes.";
            };
            package = lib.mkOption {
              type = lib.types.package;
              readOnly = true;
              # Depends on the source, so a launchd agent running it restarts once a new build is signed.
              default = pkgs.runCommand name { inherit (config) source; } ''
                mkdir -p $out/bin
                ln -s ${config.path} $out/bin/${name}
              '';
              description = "bin/${name}, pointing at the signed copy.";
            };
          };
        }
      );

      signBinaries = pkgs.writeShellApplication {
        name = "sign-binaries";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.openssl
        ];
        runtimeEnv.STATE_DIRECTORY = "/var/lib/code-signing";
        text = builtins.readFile ./sign-binaries.sh;
      };

      signArguments = lib.concatMap (
        { name, value }:
        [
          name
          value.source
          value.path
          value.identifier
        ]
      ) (lib.attrsToList config.codeSigning.binaries);
    in
    {
      options.codeSigning.binaries = lib.mkOption {
        type = lib.types.attrsOf binary;
        default = { };
        description = "Binaries that keep their privacy grants across rebuilds.";
      };

      # Before launchd reloads agents, so they start the new copy.
      config.system.activationScripts.preActivation.text = lib.mkIf (signArguments != [ ]) ''
        ${lib.getExe signBinaries} ${lib.escapeShellArgs signArguments}
      '';
    };
}

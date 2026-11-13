{
  # Ad-hoc signatures change with every build, so macOS forgets privacy grants such as Accessibility on each rebuild; binaries listed here are copied out of the store and signed with this Mac's own key instead.
  darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkOption types;
      openssl = lib.getExe pkgs.openssl;
      state = "/var/lib/code-signing";

      binary = types.submodule (
        { name, config, ... }:
        {
          options = {
            source = mkOption {
              type = types.str;
              description = "The binary to sign, usually from a package.";
            };
            identifier = mkOption {
              type = types.str;
              example = "git.felix.borders";
              description = "Signing identifier; together with the key, it is what macOS recognises across rebuilds.";
            };
            path = mkOption {
              type = types.str;
              readOnly = true;
              default = "/usr/local/libexec/${name}";
              description = "The signed copy, at a path that never changes.";
            };
            package = mkOption {
              type = types.package;
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

      binaries = lib.attrsToList config.codeSigning.binaries;
    in
    {
      options.codeSigning.binaries = mkOption {
        type = types.attrsOf binary;
        default = { };
        description = "Binaries that keep their privacy grants across rebuilds.";
      };

      # Before launchd reloads agents, so they start the new copy.
      config.system.activationScripts.preActivation.text = lib.mkIf (binaries != [ ]) ''
        # The key is made on this Mac once and never leaves it.
        install -d -m 700 ${state}
        if [ ! -s ${state}/cert.pem ]; then
          ${openssl} req -x509 -newkey rsa:2048 -nodes -days 36500 \
            -subj "/CN=$(/bin/hostname -s) code signing" \
            -addext basicConstraints=critical,CA:false \
            -addext keyUsage=critical,digitalSignature \
            -addext extendedKeyUsage=critical,codeSigning \
            -keyout ${state}/key.pem -out ${state}/cert.pem 2>/dev/null
        fi
        fingerprint=$(${openssl} x509 -noout -fingerprint -sha1 -in ${state}/cert.pem | cut -d= -f2 | tr -d :)

        keychain=
        sign() {
          name=$1 source=$2 path=$3 identifier=$4
          if [ -x "$path" ] && [ "$(cat ${state}/"$name".source 2>/dev/null)" = "$source" ]; then
            return
          fi
          if [ -z "$keychain" ]; then
            keychain=$(mktemp -d)/signing.keychain
            # codesign takes identities only from a keychain; this one lives for the run.
            ${openssl} pkcs12 -export -legacy -inkey ${state}/key.pem -in ${state}/cert.pem -passout pass:signing -out "$keychain.p12"
            /usr/bin/security create-keychain -p signing "$keychain"
            /usr/bin/security unlock-keychain -p signing "$keychain"
            /usr/bin/security import "$keychain.p12" -k "$keychain" -P signing -T /usr/bin/codesign >/dev/null
          fi
          echo "signing $name..."
          install -d "$(dirname "$path")"
          install -m 755 "$source" "$path.new"
          /usr/bin/codesign --force --keychain "$keychain" --sign "$fingerprint" --identifier "$identifier" "$path.new"
          mv -f "$path.new" "$path"
          echo "$source" > ${state}/"$name".source
        }
        ${lib.concatMapStrings (
          { name, value }:
          "sign ${
            lib.escapeShellArgs [
              name
              value.source
              value.path
              value.identifier
            ]
          }\n"
        ) binaries}
        if [ -n "$keychain" ]; then
          /usr/bin/security delete-keychain "$keychain"
          rm -rf "$(dirname "$keychain")"
        fi
      '';
    };
}

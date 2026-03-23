{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
  micsSkills = inputs.mics-skills.packages.${system};
  policies = {
    ExtensionSettings = {
      "browser-cli-controller@thalheim.io" = {
        installation_mode = "force_installed";
        install_url = "file://${micsSkills.browser-cli-extension}/browser-cli-extension.xpi";
      };
    };
  };
  librewolf = pkgs.librewolf.override {
    extraPolicies = policies;
  };
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "installing LibreWolf.app..." >&2
    targetDir='/Applications/Nix Apps'
    markerDir="$targetDir/.sources"
    mkdir -p "$targetDir" "$markerDir"

    src="${librewolf}"
    app="$src/Applications/LibreWolf.app"
    dest="$targetDir/LibreWolf.app"
    marker="$markerDir/LibreWolf.app"

    if [[ ! -f "$marker" ]] || [[ "$(cat "$marker")" != "$src" ]]; then
      echo "Syncing LibreWolf.app..." >&2
      chmod -R u+w "$dest" 2>/dev/null || true
      rm -rf "$dest"
      /usr/bin/ditto "$app" "$dest"
      echo "$src" > "$marker"
    fi
  '';
}

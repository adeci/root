{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  micsSkills = inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system};
  chromeTabGc = pkgs.callPackage ../../packages/chrome-tab-gc-extension { };
  policies = import ../../packages/librewolf-policies.nix {
    inherit (micsSkills) browser-cli-extension;
    chrome-tab-gc-extension = chromeTabGc;
  };
  librewolfMacos = pkgs.callPackage ../../packages/librewolf-macos { };
  librewolf = librewolfMacos.withPolicies policies;
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

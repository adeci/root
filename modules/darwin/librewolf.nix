# Installs the LibreWolf .app bundle to /Applications for Dock/Spotlight.
# Configuration (policies, overrides, browser-cli) is handled by
# modules/wrapped/librewolf.nix — this module only does macOS app installation.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  librewolfApp = self.packages.${pkgs.stdenv.hostPlatform.system}.librewolf.librewolfWithPolicies;
in
{
  system.activationScripts.postActivation.text = lib.mkAfter ''
    echo "installing LibreWolf.app..." >&2
    targetDir='/Applications/Nix Apps'
    markerDir="$targetDir/.sources"
    mkdir -p "$targetDir" "$markerDir"

    src="${librewolfApp}"
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

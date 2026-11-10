# Pinned here instead of following nixpkgs: Discord's 2026-11-04 rspack update
# broke 1.15.11 (black window, "i.A is not a constructor"). Recipe from nixpkgs'
# pkgs/by-name/ve/vencord.
{
  lib,
  stdenv,
  fetchFromGitHub,
  git,
  nodejs,
  pnpm_11,
  fetchPnpmDeps,
  pnpmConfigHook,
  applyPatches,
  inputs,
  plugins ? import ./plugins.nix { inherit inputs applyPatches; },
  ...
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "vencord";
  version = "1.15.16";

  src = fetchFromGitHub {
    owner = "Vendicated";
    repo = "Vencord";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aUJubLJpyLAZWiOezqFxPY6oVPgWVPQpajFqrJvrO9U=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname src;
    pnpm = pnpm_11;
    fetcherVersion = 4;
    hash = "sha256-HS8uZNepvDefjrsG3buVLFCVv7sHvazcwdpcT3EQ/78=";
  };

  nativeBuildInputs = [
    git
    nodejs
    pnpmConfigHook
    pnpm_11
  ];

  env = {
    VENCORD_REMOTE = "${finalAttrs.src.owner}/${finalAttrs.src.repo}";
    VENCORD_HASH = finalAttrs.version;
  };

  # Vencord compiles desktop userplugins and their native helpers together.
  preBuild = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: source: ''
      mkdir -p ${lib.escapeShellArg "src/userplugins/${name}"}
      cp -R ${lib.escapeShellArg "${source}/."} ${lib.escapeShellArg "src/userplugins/${name}/"}
    '') plugins
  );

  buildPhase = ''
    runHook preBuild

    pnpm run build -- --standalone --disable-updater

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    cp -r dist $out
    cp package.json $out # Presence is checked by Vesktop.

    runHook postInstall
  '';

  meta = {
    description = "Cutest Discord client mod";
    homepage = "https://github.com/Vendicated/Vencord";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
})

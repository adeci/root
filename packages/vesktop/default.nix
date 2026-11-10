# Recipe from nixpkgs' pkgs/by-name/ve/vesktop. When package.json moves to
# another Electron major, bump the electron pin below; preBuild fails until then.
{
  lib,
  pkgs,
  self,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  imagemagick,
  jq,
  libicns,
  libpulseaudio,
  makeDesktopItem,
  makeWrapper,
  nodejs,
  pipewire,
  pnpm_12,
  fetchPnpmDeps,
  pnpmConfigHook,
  ...
}:
let
  inherit (self.packages.${stdenv.hostPlatform.system}) vencord;

  # The release package.json pins. This nixpkgs has no electron_45, so use
  # upstream's release build through the builder behind electron_*-bin.
  electron =
    pkgs.callPackage "${pkgs.path}/pkgs/development/tools/electron/binary/generic.nix" { } "45.2.3"
      {
        x86_64-linux = "a87fe741f6d121285117e574da6c9a2e65210d410123bbc04713b099add0263b";
        headers = "0jpkayhvf7779fch0z85cwkpkx0x6vddbixlx6cch3xfj2xfvkqx";
      };

  splash = fetchurl {
    url = "https://raw.githubusercontent.com/adeci/wallpapers/refs/heads/main/nixos.gif";
    hash = "sha256-XGpc+QhVqBUvNxIarc50y8qvPAHwziR8pLI2TyBWXsQ=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "vesktop";
  version = "1.6.9";

  src = fetchFromGitHub {
    owner = "Vencord";
    repo = "Vesktop";
    tag = "v${finalAttrs.version}";
    hash = "sha256-UBk3wp1wuMqyY8KMSvc/URAw9awZMFQZrJgQe59PYmA=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_12;
    fetcherVersion = 5;
    hash = "sha256-efgDw/4orFP9kSWjtkyXcfkXsfYLx4LGTVNKfZ5LhdM=";
  };

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm_12
    jq
    imagemagick
    # venmic ships as a prebuilt node module.
    autoPatchelfHook
    copyDesktopItems
    # Script wrapper: the flags below expand environment variables at runtime.
    makeWrapper
  ];

  buildInputs = [
    libpulseaudio
    pipewire
    (lib.getLib stdenv.cc.cc)
  ];

  # Always load the vencord package: never downloaded files or a stale
  # vencordDir profile override.
  postPatch = ''
    substituteInPlace src/main/vencordFilesDir.ts \
      --replace-fail 'State.store.vencordDir || join(SESSION_DATA_DIR, "vencordFiles")' '"${vencord}"'

    convert -coalesce ${splash} static/splash.webp
  '';

  env.ELECTRON_SKIP_BINARY_DOWNLOAD = 1;

  preBuild = ''
    expectedMajor="$(jq -r '.devDependencies.electron | ltrimstr("^") | split(".") | .[0]' < package.json)"
    if [ "$expectedMajor" != "${lib.versions.major electron.version}" ]; then
      echo "ERROR: package.json wants Electron $expectedMajor, packages/vesktop pins ${electron.version}"
      exit 1
    fi

    # electron-builder needs a writable Electron.
    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist
  '';

  buildPhase = ''
    runHook preBuild

    pnpm build
    pnpm exec electron-builder \
      --dir \
      -c.asarUnpack="**/*.node" \
      -c.electronDist=electron-dist \
      -c.electronVersion=${electron.version}

    runHook postBuild
  '';

  postBuild = ''
    pushd build
    ${libicns}/bin/icns2png -x icon.icns
    popd
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/Vesktop
    cp -r dist/*unpacked/resources $out/opt/Vesktop/

    for file in build/icon_*x32.png; do
      file_suffix=''${file//build\/icon_}
      install -Dm0644 $file $out/share/icons/hicolor/''${file_suffix//x32.png}/apps/vesktop.png
    done

    runHook postInstall
  '';

  # Speech-dispatcher TTS unless NIXOS_SPEECH=False; native Wayland when
  # NIXOS_OZONE_WL and WAYLAND_DISPLAY are set.
  postFixup = ''
    makeWrapper ${electron}/bin/electron $out/bin/vesktop \
      --add-flags $out/opt/Vesktop/resources/app.asar \
      --run 'if [[ "''${NIXOS_SPEECH:-default}" != "False" ]]; then NIXOS_SPEECH=True; else unset NIXOS_SPEECH; fi' \
      --add-flags "\''${NIXOS_SPEECH:+--enable-speech-dispatcher}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "vesktop";
      desktopName = "Vesktop";
      exec = "vesktop %U";
      icon = "vesktop";
      startupWMClass = "Vesktop";
      genericName = "Internet Messenger";
      comment = "Alternative Discord client with Vencord built-in";
      keywords = [
        "discord"
        "vencord"
        "electron"
        "chat"
      ];
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      mimeTypes = [ "x-scheme-handler/discord" ];
    })
  ];

  meta = {
    description = "Alternative Discord client with Vencord built-in";
    homepage = "https://github.com/Vencord/Vesktop";
    changelog = "https://github.com/Vencord/Vesktop/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "vesktop";
    platforms = [ "x86_64-linux" ];
  };
})

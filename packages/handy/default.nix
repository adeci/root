# Handy 0.9.8 on Linux (source.nix) and macOS (signed DMG), with Nix-owned
# settings and model: bin/handy merges `declaredSettings` into Handy's store
# and links the declared model into its models dir before it starts; every
# other setting stays editable in the GUI.
{
  lib,
  pkgs,
  stdenvNoCC,
  fetchurl,
  undmg,
  makeShellWrapper,
  writeShellApplication,
  writers,
  ...
}:
let
  version = "0.9.8";
  inherit (stdenvNoCC.hostPlatform) isLinux isDarwin;

  # Handy's catalog default for English, pinned to the revision its catalog
  # uses. Handy counts `<models dir>/<filename>` as downloaded, so nothing is
  # fetched at runtime and the selection below survives the first start.
  model = rec {
    repo = "handy-computer/parakeet-unified-en-0.6b-gguf";
    revision = "7e948f21b7bdbac698d3318db9d350f1096f3b6c";
    filename = "parakeet-unified-en-0.6b-Q8_0.gguf";
    file = fetchurl {
      url = "https://huggingface.co/${repo}/resolve/${revision}/${filename}";
      hash = "sha256-S1C23YYr9uNGkpqvT16qzsADv6P1ZGLWyHS0HvLzh5U=";
    };
  };
  declaredModels = pkgs.linkFarm "handy-declared-models" { ${model.filename} = model.file; };

  # Keys follow Handy 0.9.8's AppSettings schema.
  declaredSettings.settings = {
    overlay_style = "live";
    paste_method = "direct";
    update_checks_enabled = false; # can't self-update in /nix/store
    autostart_enabled = false; # systemd/launchd start it
    selected_model = "${model.repo}/${model.filename}";
    shortcut_activation = "hold_or_toggle";
    model_unload_timeout = "never"; # a reload costs ~0.4 s on the next dictation
  }
  // lib.optionalAttrs isDarwin {
    # Only handy-keys can bind a lone right ⌘ (command_right).
    keyboard_implementation = "handy_keys";
  }
  // lib.optionalAttrs isLinux {
    # keyd + handy-trigger own the hotkey; handy-keys would read /dev/input.
    keyboard_implementation = "tauri";
    typing_tool = "wtype";
    # An on-demand mic opens with ~125 ms of silence and clips the first word.
    always_on_microphone = true;
    # The GUI shows the real hotkey, and Ctrl+Space (tmux) stays free. Handy
    # drops a binding missing any field, and the first start copies this file
    # verbatim, so spell out the whole ShortcutBinding.
    bindings.transcribe = {
      id = "transcribe";
      name = "Transcribe";
      description = "Converts your speech into text.";
      default_binding = "ctrl+space";
      current_binding = "super+space";
    };
  };
  declaredSettingsFile = pkgs.writeText "handy-declared-settings.json" (
    builtins.toJSON declaredSettings
  );

  setup = writeShellApplication {
    name = "handy-setup";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = builtins.readFile ./setup.sh;
  };

  trigger = writers.writePython3Bin "handy-trigger" {
    flakeIgnore = [
      "E203"
      "E501"
    ];
  } (builtins.readFile ./trigger.py);

  # Vendored until nixpkgs ships a release after 0.9.8 (source.nix carries a
  # post-0.9.8 backport and our tray patch); then this warns.
  handy-linux =
    if lib.versionAtLeast version (pkgs.handy.version or "0") then
      pkgs.callPackage ./source.nix { }
    else
      lib.warn "packages/handy: nixpkgs ships handy ${pkgs.handy.version}; drop source.nix and wrap pkgs.handy, but port tray-left-click-opens-window.patch first unless upstream's tray handles left click" pkgs.handy;

  handy-darwin = stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "handy";
    inherit version;

    src = fetchurl {
      url = "https://github.com/cjpais/Handy/releases/download/v${finalAttrs.version}/Handy_${finalAttrs.version}_aarch64.dmg";
      hash = "sha256-gawFqq9Pr6YoJrtAxc8LwMgT+2/IJVSXSA52JiB3lBc=";
    };

    nativeBuildInputs = [ undmg ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      cp -R Handy.app "$out/Applications/"
      ln -s "$out/Applications/Handy.app/Contents/MacOS/handy" "$out/bin/handy"

      runHook postInstall
    '';

    meta = {
      description = "Free, local, open-source speech-to-text application";
      homepage = "https://handy.computer/";
      platforms = [ "aarch64-darwin" ];
      mainProgram = "handy";
    };
  });

  base = if isDarwin then handy-darwin else handy-linux;

  # Tauri resolves its Resources next to the executable it was started as, so
  # on macOS start the binary inside the bundle, not bin/handy's symlink.
  handyExe =
    if isDarwin then "${base}/Applications/Handy.app/Contents/MacOS/handy" else lib.getExe base;

  # Handy finds wtype by running `which`. The DMA-BUF renderer (honoured via
  # the source.nix backport) is what keeps old pills from ghosting.
  linuxWrapperArgs = lib.optionals isLinux [
    "--prefix"
    "PATH"
    ":"
    (lib.makeBinPath [
      pkgs.wtype
      pkgs.which
    ])
    "--set"
    "WEBKIT_DISABLE_DMABUF_RENDERER"
    "0"
  ];
in
stdenvNoCC.mkDerivation {
  pname = "handy";
  inherit version;

  nativeBuildInputs = [
    makeShellWrapper
    pkgs.lndir
  ];

  buildCommand = ''
    mkdir -p $out
    lndir ${base} $out
    rm -f $out/bin/handy
    makeShellWrapper ${handyExe} $out/bin/handy \
      --run "${lib.getExe setup} ${declaredSettingsFile} ${declaredModels} || true" \
      --set HANDY_DISABLE_UPDATER 1 \
      ${lib.escapeShellArgs linuxWrapperArgs}
  ''
  + lib.optionalString isDarwin ''
    # One symlink to the signed bundle; lndir's shadow tree breaks the signature.
    rm -rf $out/Applications
    ln -s ${base}/Applications $out/Applications
  '';

  passthru = {
    unwrapped = base;
    inherit setup declaredSettingsFile declaredModels;
  }
  // lib.optionalAttrs isLinux { inherit trigger; };

  meta = {
    description = "Handy speech-to-text with Nix-declared settings";
    homepage = "https://handy.computer/";
    license = base.meta.license or lib.licenses.mit;
    mainProgram = "handy";
    platforms = [
      "x86_64-linux"
      "aarch64-darwin"
    ];
  };
}

# Local voice dictation using Whisper, with Vulkan acceleration.
{
  pkgs,
  self,
  ...
}:
let
  package = pkgs.voxtype-vulkan;
  model = "large-v3-turbo";
  noctaliaPlugin = pkgs.runCommand "noctalia-voxtype-plugin" { } ''
    mkdir -p "$out"
    cp -r ${./voxtype-noctalia}/. "$out/"
  '';

  config = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
    engine = "whisper";
    state_file = "auto";

    audio = {
      device = "default";
      sample_rate = 16000;
      max_duration_secs = 60;
    };

    hotkey = {
      enabled = true;
      key = "F13";
      mode = "push_to_talk";
    };

    whisper = {
      mode = "local";
      inherit model;
      language = "en";
      translate = false;
    };

    osd.enabled = false;

    output = {
      mode = "type";
      fallback_to_clipboard = true;
      pre_type_delay_ms = 100;
      notification = {
        on_recording_start = false;
        on_recording_stop = false;
        on_transcription = false;
      };
    };

    text = {
      spoken_punctuation = true;
      replacements = {
        "nix os" = "NixOS";
        "type script" = "TypeScript";
        "java script" = "JavaScript";
        "get hub" = "GitHub";
      };
    };
  };
in
{
  environment = {
    etc."xdg/voxtype/config.toml".source = config;
    systemPackages = [ package ];
  };

  systemd.user.services.noctalia-voxtype-plugin = {
    description = "Install and enable the Voxtype Noctalia plugin";
    before = [ "noctalia-shell.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "install-noctalia-voxtype-plugin" ''
        set -euo pipefail

        plugin_dir="$HOME/.config/noctalia/plugins"
        state_file="$HOME/.config/noctalia/plugins.json"
        mkdir -p "$plugin_dir"
        ln -sfn ${noctaliaPlugin} "$plugin_dir/voxtype"

        if [[ -f "$state_file" ]]; then
          ${pkgs.jq}/bin/jq \
            '.version = 2 | .sources //= [] | .states //= {} | .states.voxtype = { enabled: true, sourceUrl: "" }' \
            "$state_file" > "$state_file.tmp"
        else
          ${pkgs.jq}/bin/jq -n \
            '{ version: 2, sources: [], states: { voxtype: { enabled: true, sourceUrl: "" } } }' \
            > "$state_file.tmp"
        fi
        mv "$state_file.tmp" "$state_file"
      '';
    };
    wantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.voxtype = {
    description = "Local voice-to-text dictation";
    documentation = [ "https://voxtype.io" ];
    partOf = [ "graphical-session.target" ];
    requires = [ "noctalia-voxtype-plugin.service" ];
    after = [
      "graphical-session.target"
      "network-online.target"
      "noctalia-voxtype-plugin.service"
      "pipewire.service"
      "pipewire-pulse.service"
    ];
    wants = [ "network-online.target" ];
    path = [
      package
      pkgs.curl
      pkgs.wl-clipboard
      pkgs.wtype
    ];
    serviceConfig = {
      # Type=simple lets system activation finish while a missing model downloads.
      Type = "simple";
      ExecStart = pkgs.writeShellScript "voxtype-start" ''
        set -euo pipefail

        config_home=$(${pkgs.coreutils}/bin/mktemp -d)
        trap '${pkgs.coreutils}/bin/rm -rf "$config_home"' EXIT

        XDG_CONFIG_HOME="$config_home" \
          ${package}/bin/voxtype setup \
            --download \
            --model ${model} \
            --no-post-install

        exec ${package}/bin/voxtype --config ${config} daemon
      '';
      Environment = [
        "RUST_LOG=warn"
        "XDG_RUNTIME_DIR=%t"
        "WAYLAND_DISPLAY=wayland-1"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    wantedBy = [ "graphical-session.target" ];
  };

  # Collapse the compositor-facing chord into one unambiguous evdev event.
  services.keyd.keyboards.default.settings.meta.space = "f13";

  # The built-in hotkey reads evdev devices directly.
  users.users.${self.users.alex.username}.extraGroups = [ "input" ];
}

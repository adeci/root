{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.pi;

  settings = {
    lastChangelogVersion = "99.99.99";
    defaultProvider = "anthropic";
    defaultModel = "claude-opus-4-6";
    defaultThinkingLevel = "off";
    compaction.enabled = true;
  };

  extensionDir = ./extensions;
  extensionFiles = lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".ts" n) (
    builtins.readDir extensionDir
  );

  promptDir = ./prompts;
  promptFiles = lib.filterAttrs (n: t: t == "regular" && lib.hasSuffix ".md" n) (
    builtins.readDir promptDir
  );
in
{
  options.adeci.pi.enable = lib.mkEnableOption "Pi coding agent configuration";

  config = lib.mkIf cfg.enable {
    home.file = {
      ".pi/agent/settings.json".text = builtins.toJSON settings;
    }
    // lib.mapAttrs' (
      name: _:
      lib.nameValuePair ".pi/agent/extensions/${name}" {
        source = "${extensionDir}/${name}";
      }
    ) extensionFiles
    // lib.mapAttrs' (
      name: _:
      lib.nameValuePair ".pi/agent/prompts/${name}" {
        source = "${promptDir}/${name}";
      }
    ) promptFiles;
  };
}

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

  skillsDir = ./skills;
  skillDirs = lib.filterAttrs (_n: t: t == "directory") (builtins.readDir skillsDir);

  # Collect all files within each skill directory recursively
  collectSkillFiles =
    skillName:
    let
      base = "${skillsDir}/${skillName}";
      # Walk the skill directory and collect all regular files with relative paths
      walkDir =
        prefix: dir:
        lib.concatMapAttrs (
          name: type:
          let
            relPath = if prefix == "" then name else "${prefix}/${name}";
          in
          if type == "regular" then
            { ${relPath} = "${dir}/${name}"; }
          else if type == "directory" then
            walkDir relPath "${dir}/${name}"
          else
            { }
        ) (builtins.readDir dir);
    in
    walkDir "" base;

  skillFileEntries = lib.concatMapAttrs (
    skillName: _:
    lib.mapAttrs' (
      relPath: srcPath: lib.nameValuePair ".pi/agent/skills/${skillName}/${relPath}" { source = srcPath; }
    ) (collectSkillFiles skillName)
  ) skillDirs;
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
    ) promptFiles
    // skillFileEntries;
  };
}

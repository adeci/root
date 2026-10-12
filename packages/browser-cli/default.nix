{ inputs, pkgs, ... }:
inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system}.browser-cli.overrideAttrs (old: {
  postInstall =
    (old.postInstall or "")
    # bash
    + ''
            chmod u+w $out/share/skills/browser-cli $out/share/skills/browser-cli/SKILL.md
            substituteInPlace $out/share/skills/browser-cli/SKILL.md \
              --replace-fail 'name: browser-cli' 'name: browser-cli
      disable-model-invocation: true' \
              --replace-fail 'description: Control Firefox browser from the command line. Use for web automation, scraping, testing, or any browser interaction tasks.' 'description: Explicitly requested Firefox/LibreWolf automation. Load only when the user opts in to browser-cli.' \
              --replace-fail '# Usage' '# Explicit user opt-in

      Use this skill only when the user explicitly requests browser automation, for example through /skill:browser-cli. A general request to research, test, or inspect a website is not permission to control the browser.

      Permission applies to the requested task, not subsequent unrelated work. Do not delegate browser automation or switch browser tools without the same explicit permission. Use Kagi or direct HTTP for ordinary public research. Work only with tabs needed for the approved task; do not close unrelated tabs or terminate the user browser or its bridge.

      # Usage'
    '';
})

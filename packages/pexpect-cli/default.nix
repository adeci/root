{
  inputs,
  pkgs,
  ...
}:
inputs.mics-skills.packages.${pkgs.stdenv.hostPlatform.system}.pexpect-cli.overrideAttrs
  (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      chmod u+w $out/share/skills/pexpect-cli $out/share/skills/pexpect-cli/SKILL.md
      install -Dm644 ${./SKILL.md} $out/share/skills/pexpect-cli/SKILL.md
    '';
  })

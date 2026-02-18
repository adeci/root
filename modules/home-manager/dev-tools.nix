{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.adeci.dev-tools;
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.adeci.dev-tools.enable = lib.mkEnableOption "development tools (claude-code, pi, gh, jujutsu)";
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      awscli2
      llm-agents.claude-code
      llm-agents.pi
      llm-agents.ccusage
      gh
      jujutsu
      nixpkgs-review
      nix-output-monitor
      socat
      lsof
      lazygit
    ];
  };
}

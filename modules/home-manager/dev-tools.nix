{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.adeci.dev-tools;
  pkgs-master = import inputs.nixpkgs-master {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{
  options.adeci.dev-tools.enable = lib.mkEnableOption "development tools (claude-code, gh, jujutsu)";
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      awscli2
      pkgs-master.claude-code-bin
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

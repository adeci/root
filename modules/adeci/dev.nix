{
  pkgs,
  inputs,
  ...
}:
let
  pkgs-master = import inputs.nixpkgs-master {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
{

  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    awscli2
    pkgs-master.claude-code-bin # from master for latest updates
    gh
    jujutsu
    nixpkgs-review
    nix-output-monitor
    socat
    lsof
    lazygit
    usbutils
  ];

}

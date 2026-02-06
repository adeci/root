{
  pkgs,
  ...
}:
{

  programs.direnv.enable = true;

  environment.systemPackages = with pkgs; [
    awscli2
    claude-code-bin
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

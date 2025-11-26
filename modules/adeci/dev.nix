{
  inputs,
  pkgs,
  ...
}:
let
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};
in
{

  programs.direnv.enable = true;

  environment.systemPackages =
    with pkgs;
    [
      claude-code
      gh
      jujutsu
      nixpkgs-review
      nix-output-monitor
      usbmuxd
      socat
      lsof
      lazygit
      fzf
    ]
    ++ [
      inputs.adeci-nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default
      dotpkgs.btop
    ];

}

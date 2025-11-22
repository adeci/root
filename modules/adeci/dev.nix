{
  pkgs,
  inputs,
  ...
}:
{

  programs.direnv.enable = true;

  environment.systemPackages =
    with pkgs;
    [
      claude-code
      comma
      gh
      jujutsu
      nixpkgs-review
      nix-output-monitor
      usbmuxd
      socat
      lsof
    ]
    ++ [
      inputs.adeci-nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

}

{
  lib,
  pkgs,
  ...
}:
{
  home.packages =
    with pkgs;
    [
      gh
      jujutsu
      nixpkgs-review
      nix-output-monitor
      socat
      lsof
      lazygit
      screen
      tio
      pueue
      xxd
      radare2
      python3
      uv
    ]
    ++ lib.optionals stdenv.isLinux [
      dmidecode
      pciutils
      usbutils
    ];
}

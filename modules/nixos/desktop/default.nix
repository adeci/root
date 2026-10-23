# Compositor-agnostic; pair with a session module such as ../niri.
{
  imports = [
    ./apps.nix
    ./audio.nix
    ./fonts.nix
    ./graphics.nix
    ./network.nix
    ./secrets.nix
    ./theme.nix
    ../handy.nix
    ../librewolf.nix
  ];
}

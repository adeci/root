{ pkgs, ... }:
let
  # Pin prusa-slicer to a known-good nixpkgs rev — current unstable has a
  # Mesa/LLVM regression that segfaults on AMD radeonsi during GL init.
  # https://github.com/NixOS/nixpkgs/issues/347719
  pinnedPkgs = import
    (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/6c9a78c09ff4d6c21d0319114873508a6ec01655.tar.gz";
      sha256 = "0szij1c0cl4xvjhzb0cwvskkl54dyw11skb9hgmnhamcmmsm6bji";
    })
    { inherit (pkgs) system; config.allowUnfree = true; };
in
{
  environment.systemPackages = with pkgs; [
    blender
    freecad
    openscad
    audacity
    pinnedPkgs.prusa-slicer
    obs-studio
    gimp
  ];
}

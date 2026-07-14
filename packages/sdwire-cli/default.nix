{ inputs, pkgs, ... }:
pkgs.callPackage "${inputs.sdwire-cli}/default.nix" { }

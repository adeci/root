{ self, workUsers, ... }:
{
  imports = [
    workUsers.alex.darwinModule

    ../../modules/darwin/shopify.nix

    (self + "/modules/darwin/base.nix")
    (self + "/modules/darwin/librewolf.nix")
    (self + "/modules/darwin/llm-tools.nix")
    (self + "/modules/darwin/karabiner.nix")
    (self + "/modules/darwin/mouse.nix")
    (self + "/modules/darwin/aerospace")
    (self + "/modules/darwin/linux-rosetta-builder.nix")
  ];

  # SSH remains disabled until the networking step.
  services.openssh.enable = false;

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
}

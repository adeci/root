# aarch64-linux + x86_64-linux (via Rosetta 2) under vfkit/Virtualization.framework.
{ inputs, ... }:
{
  imports = [ inputs.nix-rosetta-builder.darwinModules.default ];

  nix-rosetta-builder.onDemand = true;

  system.activationScripts.preActivation.text = ''
    if ! /usr/bin/pgrep -q oahd; then
      echo "installing macOS Rosetta 2..."
      /usr/sbin/softwareupdate --install-rosetta --agree-to-license
    fi
  '';
}

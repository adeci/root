{
  darwin =
    { inputs, ... }:
    {
      imports = [ inputs.nix-rosetta-builder.darwinModules.default ];

      nix-rosetta-builder.onDemand = true;

      # Determinate Nix owns nix.conf where installed and reads this standard
      # builders file.
      environment.etc."nix/machines".text = ''
        ssh-ng://rosetta-builder aarch64-linux,x86_64-linux - 8 1 benchmark,big-parallel,kvm,nixos-test - -
      '';

      system.activationScripts.preActivation.text = ''
        if ! /usr/bin/pgrep -q oahd; then
          echo "installing macOS Rosetta 2..."
          /usr/sbin/softwareupdate --install-rosetta --agree-to-license
        fi
      '';
    };
}

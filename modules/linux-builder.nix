{
  darwin =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      builder = config.nix.linux-builder;
    in
    {
      nix.linux-builder = {
        enable = true;
        package = pkgs.darwin.linux-builder-vz;
        # The VM boots on the first build and powers off when idle; every boot starts with an empty store.
        ephemeral = true;
        # nix-darwin's default also claims kvm, which only nested virtualization provides.
        supportedFeatures = lib.mkDefault [
          "benchmark"
          "big-parallel"
        ];
        config = {
          # /dev/kvm in the VM needs macOS 15 or later on an M3 or newer.
          virtualisation.vz.nestedVirtualization = lib.elem "kvm" builder.supportedFeatures;
          # Builds are only accepted once the network is online; "any" also counts an IPv6 address that arrives before the IPv4 lease.
          networking.dhcpcd.wait = "ipv4";
          # The VM won't start when Rosetta is exposed but not installed.
          virtualisation.vz.rosetta.enable = lib.elem "x86_64-linux" builder.systems;
          # A build that runs out of memory is killed inside the VM, never on the Mac.
          zramSwap.enable = true;
          services.earlyoom.enable = true;
        };
      };
    };
}

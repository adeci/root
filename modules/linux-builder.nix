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
        # Starts on the first build, stops when idle; empty store every boot.
        ephemeral = true;
        # nix-darwin's default also claims kvm, which only nested virtualization provides.
        supportedFeatures = lib.mkDefault [
          "benchmark"
          "big-parallel"
        ];
        config = {
          # /dev/kvm in the VM needs macOS 15 or later on an M3 or newer.
          virtualisation.vz.nestedVirtualization = lib.elem "kvm" builder.supportedFeatures;
          # Builds wait for network-online; "any" fires on IPv6 before the IPv4 lease.
          networking.dhcpcd.wait = "ipv4";
          # The VM won't start when Rosetta is exposed but not installed.
          virtualisation.vz.rosetta.enable = lib.elem "x86_64-linux" builder.systems;
          # OOM kills happen inside the VM, not on the Mac.
          zramSwap.enable = true;
          services.earlyoom.enable = true;
        };
      };
    };
}

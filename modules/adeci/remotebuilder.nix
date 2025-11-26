{
  # Leviathan remote builder configuration
  # nix = {
  #   distributedBuilds = true;
  #   settings = {
  #     builders-use-substitutes = true;
  #     trusted-users = [
  #       "root"
  #       "alex"
  #     ];
  #   };
  #   buildMachines = [
  #     {
  #       protocol = "ssh-ng";
  #       hostName = "leviathan.cymric-daggertooth.ts.net";
  #       systems = [ "x86_64-linux" ];
  #       maxJobs = 7;
  #       speedFactor = 20;
  #       supportedFeatures = [
  #         "nixos-test"
  #         "benchmark"
  #         "big-parallel"
  #         "kvm"
  #       ];
  #       mandatoryFeatures = [ ];
  #       sshUser = "alex";
  #     }
  #   ];
  # };

  # programs.ssh.knownHosts.leviathan = {
  #   hostNames = [
  #     "leviathan.cymric-daggertooth.ts.net"
  #     "192.168.50.189"
  #   ];
  #   publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEtV2xoOv+N4c5sg5oBqM/Xy+aZHf+5GHOhzXKYduXG";
  # };
}

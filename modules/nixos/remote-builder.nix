{
  config,
  pkgs,
  ...
}:
{
  # SSH key pair for remote builder connections (auto-generated, shared across workstations)
  clan.core.vars.generators.remote-builder-ssh-key = {
    share = true;
    files = {
      id_ed25519 = { };
      "id_ed25519.pub".secret = false;
    };
    runtimeInputs = [ pkgs.openssh ];
    script = ''
      ssh-keygen -t ed25519 -N "" -f "$out"/id_ed25519
    '';
  };

  nix = {
    # Off — use `nrb` to opt in per build. Avoids latency when traveling.
    distributedBuilds = false;

    buildMachines = [
      {
        hostName = "leviathan";
        system = "x86_64-linux";
        protocol = "ssh-ng";
        maxJobs = 16;
        speedFactor = 10;
        supportedFeatures = [
          "nixos-test"
          "big-parallel"
          "kvm"
        ];
        sshUser = "root";
        sshKey = config.clan.core.vars.generators.remote-builder-ssh-key.files.id_ed25519.path;
      }
    ];

  };

  # Accept leviathan's host key on first connection
  programs.ssh.extraConfig = ''
    Host leviathan
      StrictHostKeyChecking accept-new
  '';
}

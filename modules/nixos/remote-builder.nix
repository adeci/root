{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  harmoniaKeyPath = self + "/vars/shared/harmonia-signing-key/signing-key.pub/value";
  hasHarmonia = builtins.pathExists harmoniaKeyPath;
in
{
  options.adeci.remote-builder.automatic = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      When true, nix.distributedBuilds is enabled and builds transparently offload.
      When false, buildMachines is configured but the user must opt in per build
      via --max-jobs 0.
    '';
  };

  config = {
    # Vars generator: SSH key pair for remote builder connections (auto-generated)
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
      distributedBuilds = config.adeci.remote-builder.automatic;

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

      # Harmonia substituter — fetch cached builds from leviathan (only when harmonia is deployed)
      settings = lib.mkIf hasHarmonia {
        extra-substituters = [ "http://leviathan:5000" ];
        extra-trusted-public-keys = [
          (lib.strings.trim (builtins.readFile harmoniaKeyPath))
        ];
      };
    };

    # Accept leviathan's host key on first connection
    programs.ssh.extraConfig = ''
      Host leviathan
        StrictHostKeyChecking accept-new
    '';
  };
}

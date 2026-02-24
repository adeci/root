{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.adeci.remote-builder;
in
{
  options.adeci.remote-builder = {
    enable = lib.mkEnableOption "remote builder (offload nix builds to leviathan)";

    automatic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, nix.distributedBuilds is enabled and builds transparently offload.
        When false, buildMachines is configured but the user must opt in per build
        via --builders or --max-jobs 0.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
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
      distributedBuilds = cfg.automatic;

      buildMachines = [
        {
          hostName = "leviathan";
          system = "x86_64-linux";
          protocol = "ssh-ng";
          maxJobs = 128;
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

      # Harmonia substituter — fetch cached builds from leviathan
      settings = {
        extra-substituters = [ "http://leviathan:5000" ];
        extra-trusted-public-keys = [
          (lib.strings.trim (
            builtins.readFile (self + "/vars/shared/harmonia-signing-key/signing-key.pub/value")
          ))
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

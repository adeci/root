{
  nixos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      tailscaleTravel = pkgs.writeShellApplication {
        name = "tailscale-travel";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.curl
          pkgs.gawk
          pkgs.gnugrep
          pkgs.tailscale
        ];
        runtimeEnv.DEFAULT_EXIT_NODE = config.tailscaleTravel.defaultExitNode;
        text = builtins.readFile ./tailscale-travel.sh;
      };
    in
    {
      options.tailscaleTravel.defaultExitNode = lib.mkOption {
        type = lib.types.str;
        description = "Exit node `tailscale-travel away` uses when none is given.";
      };

      config.environment.systemPackages = [ tailscaleTravel ];
    };
}

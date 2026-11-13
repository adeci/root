{
  _class = "clan.service";

  manifest = {
    name = "@adeci/monitoring";
    description = "Prometheus + Loki + Grafana observability stack with Alloy agents";
    categories = [ "Utility" ];
    readme = builtins.readFile ./README.md;
  };

  roles.agent = import ./agent.nix;
  roles.server = import ./server.nix;

  perMachine.nixosModule =
    { lib, pkgs, ... }:
    let
      # Agents push with the password; the server's nginx checks it against the htpasswd.
      pushCredentials = {
        share = true;
        files = {
          username.secret = false;
          password = { };
          htpasswd = { };
        };
        runtimeInputs = [
          pkgs.openssl
          pkgs.apacheHttpd
        ];
        script = ''
          echo -n "alloy" > "$out/username"
          openssl rand -hex 32 > "$out/password"
          htpasswd -nbB "$(cat "$out/username")" "$(cat "$out/password")" > "$out/htpasswd"
        '';
      };
    in
    {
      options.monitoring = {
        scrapeTargets = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Local Prometheus endpoints, as `address:port` by job name, that the agent scrapes and ships to the server.";
          example = {
            kea = "127.0.0.1:9547";
          };
        };

        textfileDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/alloy/textfile";
          readOnly = true;
          description = "Directory whose `*.prom` files the agent ships with the node metrics.";
        };
      };

      config.clan.core.vars.generators = {
        prometheus-auth = pushCredentials;
        loki-auth = pushCredentials;
      };
    };
}

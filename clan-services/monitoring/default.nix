let
  textfileDirectory =
    { lib, ... }:
    {
      options.monitoring.textfileDirectory = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/prometheus-node-exporter/textfile";
        readOnly = true;
        description = "Directory whose `*.prom` files node_exporter serves with the node metrics.";
      };
    };
in
{
  _class = "clan.service";

  manifest = {
    name = "@adeci/monitoring";
    description = "Prometheus + Loki + Grafana observability stack, scraping node_exporter and receiving the journal from Vector";
    categories = [ "Utility" ];
    readme = builtins.readFile ./README.md;
  };

  roles.agent = import ./agent.nix;
  roles.server = import ./server.nix;

  perMachine.nixosModule =
    { lib, pkgs, ... }:
    {
      imports = [ textfileDirectory ];

      options.monitoring.exporters = lib.mkOption {
        type = lib.types.attrsOf lib.types.port;
        readOnly = true;
        description = "The ports of this machine's exporters by job, from its agent settings; the machine's modules make each exporter listen on its port.";
      };

      # Agents push their journal with the password; the server's nginx checks it against the htpasswd.
      config.clan.core.vars.generators.loki-auth = {
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
        # The username dates from the Alloy agents; the stored credential keeps it.
        script = ''
          echo -n "alloy" > "$out/username"
          openssl rand -hex 32 > "$out/password"
          htpasswd -nbB "$(cat "$out/username")" "$(cat "$out/password")" > "$out/htpasswd"
        '';
      };
    };

  perMachine.darwinModule = textfileDirectory;
}

# Keyed by edge machine. A stream forwards its listen port to upstream and opens it on the edge's firewalls.
let
  inherit (import ./tailscale) domain;
in
{
  edges = {
    conduit = {
      provider = "hcloud";
      firewall = {
        # SSH is Tailscale-only; for Hetzner rescue, temporarily add tcp/22 here and apply.
        staticRules = [
          {
            description = "HTTP (Zipline)";
            protocol = "tcp";
            port = 80;
          }
          {
            description = "HTTPS (Zipline)";
            protocol = "tcp";
            port = 443;
          }
          {
            description = "Tailscale direct WireGuard endpoint";
            protocol = "udp";
            port = 41641;
          }
        ];
      };
    };
  };

  streams = {
    conduit = [
      {
        name = "minecraft-dj2";
        description = "Minecraft bros dj2";
        protocol = "tcp";
        listen = 25568;
        upstream = "leviathan.${domain}:25568";
      }
      {
        name = "minecraft-dj2-voice";
        description = "Minecraft bros dj2 voice";
        protocol = "udp";
        listen = 24457;
        upstream = "leviathan.${domain}:24457";
      }

      {
        name = "minecraft-gab";
        description = "Minecraft bros gab";
        protocol = "tcp";
        listen = 25573;
        upstream = "leviathan.${domain}:25573";
      }
      {
        name = "minecraft-gab-voice";
        description = "Minecraft bros gab voice";
        protocol = "udp";
        listen = 24460;
        upstream = "leviathan.${domain}:24460";
      }
    ];
  };
}

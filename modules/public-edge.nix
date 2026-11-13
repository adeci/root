{
  nixos =
    { config, lib, ... }:
    let
      inherit (config.publicEdge) streams;
      safeName =
        builtins.replaceStrings
          [
            "-"
            "."
          ]
          [
            "_"
            "_"
          ];

      listenerKey = stream: "${stream.protocol}:${toString stream.listen}";

      names = map (stream: stream.name) streams;
      listenerKeys = map listenerKey streams;

      streamsFor = protocol: lib.filter (stream: stream.protocol == protocol) streams;
      publicPortsFor = protocol: lib.unique (map (stream: stream.listen) (streamsFor protocol));

      mkListen =
        stream: "${toString stream.listen}${lib.optionalString (stream.protocol == "udp") " udp"}";
      mkServer =
        stream:
        let
          variable = "upstream_${safeName stream.name}_${stream.protocol}_${toString stream.listen}";
        in
        ''
          # ${stream.description}
          server {
            listen ${mkListen stream};
            set ${"$"}${variable} "${stream.upstream}";
            proxy_pass ${"$"}${variable};
          }
        '';
    in
    {
      options.publicEdge.streams = lib.mkOption {
        default = [ ];
        description = "Public L4 streams: each forwards its listen port to its upstream and opens that port in the firewall.";
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                description = "Unique on this machine.";
              };
              description = lib.mkOption { type = lib.types.str; };
              protocol = lib.mkOption {
                type = lib.types.enum [
                  "tcp"
                  "udp"
                ];
              };
              listen = lib.mkOption {
                type = lib.types.ints.between 1 65535;
                description = "Public port; each protocol/port pair binds at most one stream.";
              };
              upstream = lib.mkOption {
                type = lib.types.strMatching ".+:[0-9]+";
                description = "host:port to forward to.";
              };
            };
          }
        );
      };

      config = lib.mkMerge [
        {
          assertions = [
            {
              assertion = config.services.tailscale.enable;
              message = "public-edge ${config.networking.hostName}: needs services.tailscale for tailscale0 and MagicDNS.";
            }
          ];

          # A vhost or location with its own add_header must repeat this one.
          services.nginx.commonHttpConfig = ''
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
          '';

          # Out-of-band fallback: the provider's web console, log in as the primary user.
          services.openssh.openFirewall = false;
          networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
        }
        (lib.mkIf (streams != [ ]) {
          assertions = [
            {
              assertion = names == lib.unique names;
              message = "public-edge ${config.networking.hostName}: stream names must be unique.";
            }
            {
              assertion = listenerKeys == lib.unique listenerKeys;
              message = "public-edge ${config.networking.hostName}: only one stream may bind each protocol/listen port.";
            }
          ];

          services.nginx = {
            enable = true;
            # A variable proxy_pass lets nginx reload while MagicDNS is down; Quad100 resolves its names.
            streamConfig = lib.mkAfter ''
              resolver 100.100.100.100 valid=30s ipv6=off;

              ${lib.concatMapStringsSep "\n" mkServer streams}
            '';
          };

          systemd.services.nginx = {
            after = [ "tailscaled.service" ];
            wants = [ "tailscaled.service" ];
          };

          networking.firewall = {
            allowedTCPPorts = publicPortsFor "tcp";
            allowedUDPPorts = publicPortsFor "udp";
          };
        })
      ];
    };
}

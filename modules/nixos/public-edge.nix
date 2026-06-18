{
  config,
  lib,
  self,
  ...
}:
let
  streams = self.resources.ingress.streams.${config.networking.hostName} or [ ];
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

  validProtocols = [
    "tcp"
    "udp"
  ];
  isPort = port: builtins.isInt port && port > 0 && port <= 65535;
  hasPortSuffix = upstream: builtins.match ".+:[0-9]+" upstream != null;
  listenerKey = stream: "${stream.protocol}:${toString stream.listen}";

  names = map (stream: stream.name) streams;
  listenerKeys = map listenerKey streams;
  invalidProtocols = lib.filter (stream: !(lib.elem stream.protocol validProtocols)) streams;
  invalidListenPorts = lib.filter (stream: !(isPort stream.listen)) streams;
  invalidUpstreams = lib.filter (
    stream: !(builtins.isString stream.upstream && hasPortSuffix stream.upstream)
  ) streams;

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
  config = lib.mkIf (streams != [ ]) {
    assertions = [
      {
        assertion = invalidProtocols == [ ];
        message = "public-edge ${config.networking.hostName}: protocols must be tcp or udp.";
      }
      {
        assertion = invalidListenPorts == [ ];
        message = "public-edge ${config.networking.hostName}: listen ports must be integers from 1 to 65535.";
      }
      {
        assertion = invalidUpstreams == [ ];
        message = "public-edge ${config.networking.hostName}: upstreams must be host:port strings.";
      }
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
      streamConfig = lib.mkAfter ''
        # Variable-backed proxy_pass makes nginx reload independent from
        # current Tailnet DNS availability. Quad100 resolves MagicDNS names.
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
  };
}

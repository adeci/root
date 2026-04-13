_: {
  _class = "clan.service";

  manifest = {
    name = "@adeci/tailscale";
    description = "Tailscale VPN - Zero-config mesh networking";
    categories = [ "Utility" ];
    readme = builtins.readFile ./README.md;
  };

  roles.peer = {
    description = "Tailscale peer that connects to the mesh VPN network";
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          accept-routes = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Accept subnet routes advertised by other Tailscale nodes.";
          };

          accept-dns = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Accept DNS configuration from Tailscale (MagicDNS). Set to false to
              prevent Tailscale from modifying systemd-resolved, which avoids DNS
              conflicts when on a network behind your own Tailscale subnet router.
              When false, .ts.net resolution is configured via dns-delegate.
            '';
          };

          tailnet-domain = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Tailnet domain name (e.g. "cymric-daggertooth.ts.net"). When set and
              accept-dns is false, this is added as a search domain so short hostnames
              like "janus" resolve via MagicDNS.
            '';
          };

          advertise-routes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "List of CIDR ranges to advertise as subnet routes (e.g. \"10.99.0.0/24\").";
          };

          exitnode-optimization = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Enable Linux kernel optimizations for Tailscale exit nodes and subnet routers.
              This applies ethtool settings for improved UDP throughput on Linux 6.2+ kernels.
            '';
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            generatorName = "tailscale-${instanceName}";

            # Extract custom options and filter them out from settings passed to nixos module
            acceptRoutes = settings.accept-routes or false;
            acceptDns = settings.accept-dns or true;
            tailnetDomain = settings.tailnet-domain or "";
            advertiseRoutes = settings.advertise-routes or [ ];
            exitnodeOptimization = settings.exitnode-optimization or false;
            cleanSettings = lib.filterAttrs (
              n: _v:
              !builtins.elem n [
                "accept-routes"
                "accept-dns"
                "tailnet-domain"
                "advertise-routes"
                "exitnode-optimization"
              ]
            ) settings;

            # Build extraUpFlags from structured options + any manually specified flags
            extraFlags =
              (cleanSettings.extraUpFlags or [ ])
              ++ lib.optional acceptRoutes "--accept-routes"
              ++ lib.optional (!acceptDns) "--accept-dns=false"
              ++ lib.optional (
                advertiseRoutes != [ ]
              ) "--advertise-routes=${lib.concatStringsSep "," advertiseRoutes}";

            finalSettings =
              (lib.filterAttrs (n: _v: n != "extraUpFlags") cleanSettings)
              // {
                authKeyFile = lib.mkDefault config.clan.core.vars.generators."${generatorName}".files.auth_key.path;
              }
              // lib.optionalAttrs (extraFlags != [ ]) {
                extraUpFlags = extraFlags;
              };
          in
          {
            clan.core.vars.generators."${generatorName}" = {
              share = true;
              files.auth_key = { };
              runtimeInputs = [ pkgs.coreutils ];

              prompts.auth_key = {
                description = "Tailscale auth key for instance '${instanceName}'";
                type = "hidden";
                persist = true;
              };

              script = # bash
                ''
                  cat "$prompts"/auth_key > "$out"/auth_key
                '';
            };

            services.tailscale = finalSettings // {
              enable = true;
            };

            # Dead simple service to reapply Tailscale flags when config changes
            systemd.services."tailscale-apply-flags-${instanceName}" =
              lib.mkIf ((finalSettings.extraUpFlags or [ ]) != [ ])
                {
                  description = "Apply Tailscale flags for ${instanceName}";
                  after = [ "tailscaled.service" ];
                  wants = [ "tailscaled.service" ];

                  # Trigger restart when flags change
                  restartTriggers = [ (builtins.toJSON finalSettings.extraUpFlags) ];

                  script = # bash
                    ''
                      ${pkgs.tailscale}/bin/tailscale up --reset ${
                        lib.escapeShellArgs (finalSettings.extraUpFlags or [ ])
                      }
                    '';

                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };

                  wantedBy = [ "multi-user.target" ];
                };

            # When accept-dns is false, use systemd's dns-delegate feature (systemd 258+)
            # to route .ts.net queries to MagicDNS. This is interface-independent —
            # no networkd management of tailscale0 needed, no race conditions.
            services.resolved.dnsDelegates.tailscale = lib.mkIf (!acceptDns) {
              Delegate = {
                DNS = "100.100.100.100";
                Domains = [ "ts.net" ] ++ lib.optional (tailnetDomain != "") tailnetDomain;
                DefaultRoute = false;
              };
            };

            # When accepting subnet routes, prefer direct local routes over Tailscale.
            # Adds a routing policy rule before table 52 that checks the main table
            # for connected routes (suppress_prefixlength 0 ignores the default route):
            #   - At home on WiFi: direct route to 10.10.0.0/24 wins → local path
            #   - Away from home: no direct route → falls through to Tailscale subnet routing
            # Enable IP forwarding for subnet routing (mkDefault — won't conflict if router.nix sets it too)
            boot.kernel.sysctl = lib.mkIf (advertiseRoutes != [ ]) {
              "net.ipv4.ip_forward" = lib.mkDefault 1;
              "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
            };

            # Add ethtool when optimization is enabled
            environment.systemPackages = [ pkgs.tailscale ] ++ lib.optional exitnodeOptimization pkgs.ethtool;

            # NetworkManager dispatcher scripts
            networking.networkmanager.dispatcherScripts =
              # Prefer direct local routes over Tailscale subnet routes.
              # Priority 5200 is outside Tailscale's managed range (5210-5310)
              # so it won't be cleared when Tailscale rebuilds its rules.
              # Re-applied on every interface up event as a safety net.
              lib.optionals acceptRoutes [
                {
                  source = pkgs.writeShellScript "tailscale-local-routes" ''
                    [ "$2" != "up" ] && exit 0
                    ${pkgs.iproute2}/bin/ip rule add priority 5200 lookup main suppress_prefixlength 0 2>/dev/null || true
                  '';
                  type = "basic";
                }
              ]
              ++ lib.optionals exitnodeOptimization [
                {
                  source = pkgs.writeShellScript "tailscale-optimize-${instanceName}" ''
                    # NetworkManager dispatcher passes interface name as $1 and action as $2
                    INTERFACE="$1"
                    ACTION="$2"

                    # Only run on interface up events
                    if [ "$ACTION" != "up" ]; then
                      exit 0
                    fi

                    # Check if this is the default route interface
                    DEFAULT_IFACE=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 2>/dev/null | ${pkgs.coreutils}/bin/cut -f 5 -d " ")

                    if [ "$INTERFACE" != "$DEFAULT_IFACE" ]; then
                      exit 0
                    fi

                    # Apply optimizations
                    echo "Applying Tailscale exit node optimizations to interface: $INTERFACE"
                    ${pkgs.ethtool}/sbin/ethtool -K "$INTERFACE" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || {
                      # These settings may not be available on all NICs/kernels, which is fine
                      exit 0
                    }
                  '';
                  type = "basic";
                }
              ];
          };
      };
  };
}

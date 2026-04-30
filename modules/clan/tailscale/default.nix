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

            addLocalRoutesRule = # bash
              ''
                ${pkgs.iproute2}/bin/ip rule add priority 5200 lookup main suppress_prefixlength 0 2>/dev/null || true
              '';
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

            # Workaround: tailscale#1227 — accept-routes overrides local routes.
            # ip rule at priority 5200 (outside Tailscale's 5210-5310 range) makes
            # direct routes win over Tailscale's table 52. Gets cleared on network
            # changes and sleep/resume, so we re-add from multiple hooks.
            systemd.services."tailscale-local-routes-${instanceName}" = lib.mkIf acceptRoutes {
              description = "Prefer local routes over Tailscale subnet routes for ${instanceName}";
              after = [
                "tailscaled.service"
              ]
              ++ lib.optional (
                (finalSettings.extraUpFlags or [ ]) != [ ]
              ) "tailscale-apply-flags-${instanceName}.service";
              wants = [
                "tailscaled.service"
              ]
              ++ lib.optional (
                (finalSettings.extraUpFlags or [ ]) != [ ]
              ) "tailscale-apply-flags-${instanceName}.service";
              wantedBy = [ "multi-user.target" ];
              restartTriggers = [ (builtins.toJSON (finalSettings.extraUpFlags or [ ])) ];
              script = addLocalRoutesRule;
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
            };

            powerManagement.resumeCommands = lib.mkIf acceptRoutes addLocalRoutesRule;

            boot.kernel.sysctl = lib.mkIf (advertiseRoutes != [ ]) {
              "net.ipv4.ip_forward" = lib.mkDefault 1;
              "net.ipv6.conf.all.forwarding" = lib.mkDefault 1;
            };

            environment.systemPackages = [ pkgs.tailscale ] ++ lib.optional exitnodeOptimization pkgs.ethtool;

            networking.networkmanager.dispatcherScripts =
              lib.optionals acceptRoutes [
                {
                  source = pkgs.writeShellScript "tailscale-local-routes" ''
                    case "$2" in up|connectivity-change) ;; *) exit 0 ;; esac
                    ${addLocalRoutesRule}
                  '';
                  type = "basic";
                }
              ]
              ++ lib.optionals exitnodeOptimization [
                {
                  source = pkgs.writeShellScript "tailscale-optimize-${instanceName}" ''
                    [ "$2" = "up" ] || exit 0
                    DEFAULT_IFACE=$(${pkgs.iproute2}/bin/ip -o route get 8.8.8.8 2>/dev/null | ${pkgs.coreutils}/bin/cut -f 5 -d " ")
                    [ "$1" = "$DEFAULT_IFACE" ] || exit 0
                    ${pkgs.ethtool}/sbin/ethtool -K "$1" rx-udp-gro-forwarding on rx-gro-list off 2>/dev/null || true
                  '';
                  type = "basic";
                }
              ];
          };
      };
  };
}

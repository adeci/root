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

            # Extract the custom option and filter it out from the settings passed to nixos module
            exitnodeOptimization = settings.exitnode-optimization or false;
            cleanSettings = lib.filterAttrs (n: _v: n != "exitnode-optimization") settings;

            finalSettings = cleanSettings // {
              authKeyFile = lib.mkDefault config.clan.core.vars.generators."${generatorName}".files.auth_key.path;
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

              script = ''
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

                  script = ''
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

            # Add ethtool when optimization is enabled
            environment.systemPackages = [ pkgs.tailscale ] ++ lib.optional exitnodeOptimization pkgs.ethtool;

            # Use NetworkManager dispatcher for cleaner interface optimization
            networking.networkmanager.dispatcherScripts = lib.mkIf exitnodeOptimization [
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

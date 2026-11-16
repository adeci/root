{
  b2,
  cloudflare,
  lan,
  tailnet,
  ...
}@inventory:
{
  atuin = {
    module = {
      name = "@adeci/atuin";
      input = "self";
    };
    roles.server.machines.sequoia = { };
    roles.client.machines = {
      aegis = { };
      icarus = { };
      modus = { };
      praxis = { };
    };
    roles.client.settings.user = "alex";
  };

  harmonia = {
    module = {
      name = "@adeci/harmonia";
      input = "self";
    };
    roles.server.machines.leviathan = { };
    roles.client.tags = [ "adeci-net" ];
  };

  monitoring =
    let
      ntfyPort = cloudflare.tunnels.sequoia.ntfy.port;
    in
    {
      module = {
        name = "@adeci/monitoring";
        input = "self";
      };
      roles = {
        agent = {
          tags = {
            adeci-net = { };
            portable.settings = {
              alwaysOn = false;
              # Battery health, on Linux and macOS.
              extraCollectors = [ "powersupplyclass" ];
            };
          };
          machines = {
            # A VM: its disk is QEMU's, with no SMART data.
            conduit.settings.smart.enable = false;

            janus.settings = import ../machines/janus/monitoring inventory;

            leviathan.settings = import ../machines/leviathan/monitoring.nix;
          };
        };
        server = {
          settings = {
            agentDomain = tailnet.domain;
            alertDelivery.ntfy = {
              enable = true;
              topic = "alerts";
              configGenerator = "ntfy-alerts";
            };
          };
          machines = {
            sequoia.settings = {
              host = "sequoia.${tailnet.domain}";
              grafana = {
                enable = true;
                domain = lan.dns.atlas.host;
                homeDashboard = "fleet";
              };
              retentionDays = 30;
              loki.retentionDays = 30;
              alertDelivery.ntfy.baseUrl = "http://127.0.0.1:${toString ntfyPort}";
            };

            # Outside the house: it still sees the fleet when home is offline, and alerts when sequoia cannot.
            conduit.settings = {
              backup = true;
              retentionDays = 3;
              alertDelivery.ntfy.baseUrl = "http://[::1]:2586";
            };
          };
        };
      };
    };

  nixbot =
    let
      tunnel = cloudflare.tunnels.leviathan.nixbot;
    in
    {
      module = {
        name = "@adeci/nixbot";
        input = "self";
      };

      roles.server.machines.leviathan.settings = {
        domain = tunnel.host;
        listenPort = tunnel.port;
        buildSystems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];
        # leviathan is shared with other users and the LLM host; keep CI bounded.
        evalWorkerCount = 8;
        evalMaxMemorySize = 4096;
        buildConcurrency = 8;
        admins = [
          "github:adeci"
          "github:fzakaria"
        ];
        prApproval = {
          enable = true;
          trustedAssociations = [
            "OWNER"
            "MEMBER"
            "COLLABORATOR"
          ];
        };
        github = {
          appId = 5474567;
          oauthId = "Iv23liPuk6XhuDT6Owtz";
          userAllowlist = [
            "adeci"
            "ddeci"
            "fzakaria"
          ];
        };
        # Signs and notarizes Mac software with rcodesign, away from a Mac.
        sharedEffectSecrets.apple_developer_id = {
          key = {
            description = "Developer ID Application private key (PEM), the one its signing request was made from";
            multiline = true;
          };
          certificate = {
            description = "Developer ID Application certificate (PEM: openssl x509 -inform der -in developerID_application.cer)";
            multiline = true;
          };
          notary_key = {
            description = "App Store Connect API key as JSON (rcodesign encode-app-store-connect-api-key)";
            multiline = true;
          };
        };
        sharedEffectSecrets.github_release.token.description = "GitHub token that publishes releases";
        effectSecrets = {
          "github:fzakaria/rewindvm" = [ "cachix" ];
          "github:adeci/earwig" = [
            "apple_developer_id"
            "github_release"
          ];
        };
      };
    };

  builders = {
    module = {
      name = "@adeci/remote-builder";
      input = "self";
    };
    roles.server.machines = {
      daedalus.settings = {
        systems = [ "aarch64-darwin" ];
        maxJobs = 2;
        supportedFeatures = [ "big-parallel" ];
        linuxBuilder = {
          systems = [ "aarch64-linux" ];
          maxJobs = 4;
          supportedFeatures = [
            "benchmark"
            "big-parallel"
            "kvm"
            "nixos-test"
          ];
        };
      };

      leviathan.settings = {
        systems = [
          "x86_64-linux"
          "i686-linux"
        ];
        maxJobs = 16;
        speedFactor = 10;
      };
    };
    roles.client.machines = {
      aegis = { };
      bramble = { };
      icarus = { };
      leviathan = { };
      modus = { };
      praxis = { };
    };
  };

  restic =
    let
      bucket = b2.buckets.resticBackups;
    in
    {
      module = {
        name = "@adeci/restic";
        input = "self";
      };

      roles.client.settings = {
        repositoryBase = "s3:${b2.s3Endpoint}/${bucket.name}";
        inherit (bucket) credentials;
      };

      roles.client.machines = {
        conduit = { };
        sequoia = { };
        leviathan = { };
        lachesis = { };
        janus = { };
      };
    };

  security-keys = {
    module = {
      name = "@adeci/security-keys";
      input = "self";
    };
    roles.default = {
      settings.keys = [
        {
          name = "spark";
          owner = "alex";
        }
        {
          name = "ember";
          owner = "alex";
        }
      ];
      machines.aegis.settings.use = [
        "ember"
      ];
      machines.modus.settings.use = [
        "spark"
      ];
      machines.praxis.settings.use = [
        "spark"
      ];
    };
  };

  sshd = {
    module = {
      name = "sshd";
      input = "clan-core";
    };
    roles.server.tags = [ "adeci-net" ];
    roles.client.tags = [ "adeci-net" ];
  };

  state-version = {
    module = {
      name = "importer";
      input = "clan-core";
    };
    roles.default.tags = [ "all" ];
    roles.default.settings.extraModules = [
      {
        clan.core.settings.state-version.enable = true;
      }
    ];
  };

  syncthing = {
    module = {
      name = "syncthing";
      input = "clan-core";
    };
    roles.peer = {
      machines = {
        aegis = { };
        modus = { };
        praxis = { };
        sequoia = { };
      };

      extraModules = [
        { services.syncthing.user = "alex"; }
      ];

      settings = {
        extraDevices = {
          razr = {
            id = "PXAMRHT-G7OA3GU-VMEBK2F-TPQTS55-4A4KBXO-AWATRBJ-FZ7KH7L-3OU2GQA";
            name = "razr";
          };
        };

        folders = {
          notes = {
            path = "/home/alex/notes";
          };
          study = {
            path = "/home/alex/study";
          };
        };

      };
    };
  };

  "adeci-net" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer.tags = [ "adeci-net" ];
  };

  "adeci-net-ephemeral" = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer.tags = [ "adeci-net-ephemeral" ];
  };

  wifi = {
    module = {
      name = "wifi";
      input = "clan-core";
    };
    roles.default = {
      tags = [ "wifi-preload" ];
      settings.networks = {
        home = { };
        hotspot = { };
      };
    };
  };
}

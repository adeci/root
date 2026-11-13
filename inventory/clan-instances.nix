{
  b2,
  cloudflare,
  tailnet,
  ...
}@inventory:
let
  minimalJournal = {
    journal = {
      mode = "explicit";
      include = [
        "alloy"
        "sshd"
        "tailscaled"
        "tailscaled-autoconnect"
        "tailscaled-set"
      ];
    };
  };
in
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
      ntfyHost = "ntfy.decio.us";
      ntfyPort = cloudflare.tunnels.sequoia.${ntfyHost}.port;
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
            portable.settings.alwaysOn = false;
          };
          machines = {
            aegis.settings = minimalJournal;
            atropos.settings = minimalJournal;
            clotho.settings = minimalJournal;
            kasha.settings = minimalJournal;
            lachesis.settings = minimalJournal;
            modus.settings = minimalJournal;
            praxis.settings = minimalJournal;
            proteus.settings = minimalJournal;

            janus.settings = import ../machines/janus/monitoring inventory;

            leviathan.settings = import ../machines/leviathan/monitoring.nix;
          };
        };
        server.machines.sequoia.settings = {
          host = "sequoia.${tailnet.domain}";
          grafana = {
            enable = true;
            homeDashboard = "network";
          };
          retentionDays = 30;
          loki.retentionHours = 168;
          alertDelivery.ntfy = {
            enable = true;
            baseUrl = "http://127.0.0.1:${toString ntfyPort}";
            topic = "atlas-alerts";
            configGenerator = "ntfy-alerts";
          };
        };
      };
    };

  nixbot =
    let
      domain = "nixbot.decio.us";
    in
    {
      module = {
        name = "@adeci/nixbot";
        input = "self";
      };

      roles.server.machines.leviathan.settings = {
        inherit domain;
        listenPort = cloudflare.tunnels.leviathan.${domain}.port;
        # aarch64 only builds on bramble (Pi 4) and times out.
        buildSystems = [ "x86_64-linux" ];
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
        effectSecrets."github:fzakaria/rewindvm" = [ "cachix" ];
      };
    };

  builders = {
    module = {
      name = "@adeci/remote-builder";
      input = "self";
    };
    roles.server.machines = {
      bramble.settings = {
        systems = [ "aarch64-linux" ];
        maxJobs = 2;
        speedFactor = 1;
        supportedFeatures = [ ];
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

{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  port = 11435;
  stateDir = "/var/lib/llm-weights";

  inherit (self.resources.llm) models weights;
  localModels = lib.filterAttrs (_: model: model.backend.type == "local-gguf") models;
  localWeightIds = lib.unique (map (model: model.backend.weight) (builtins.attrValues localModels));
  localWeights = lib.genAttrs localWeightIds (id: weights.${id});

  cudaPackages = pkgs.cudaPackages // {
    flags = pkgs.cudaPackages.flags // {
      cmakeCudaArchitecturesString = "70";
    };
  };

  llamaCpp = pkgs.llama-cpp.override {
    cudaSupport = true;
    inherit cudaPackages;
  };

  prepareCommand = pkgs.callPackage ./weights { };

  llamaServer = "${llamaCpp}/bin/llama-server";
  hfTokenPath = config.clan.core.vars.generators.huggingface-read-token.files.token.path;

  weightsManifest = pkgs.writeText "llm-weights-manifest.json" (
    builtins.toJSON {
      baseDir = stateDir;
      weights = lib.mapAttrs (_: weight: {
        inherit (weight) displayName entrypoint;
        source = {
          inherit (weight.source) repo revision;
        };
        inherit (weight.source) files;
      }) localWeights;
    }
  );

  mkModel =
    _name: model:
    let
      weight = weights.${model.backend.weight};
      contextWindow = model.contextWindow or weight.nativeContextWindow;
      modelPath = "${stateDir}/models/${model.backend.weight}/${weight.entrypoint}";
    in
    {
      ttl = model.ttl or 1800;
      cmd = ''
        ${llamaServer} --host 127.0.0.1 --port ''${PORT} \
          -m ${lib.escapeShellArg modelPath} \
          -ngl 999 \
          --split-mode layer \
          --tensor-split 1,1 \
          -c ${toString contextWindow} \
          -np 1 \
          --no-webui
      '';
    };
in
{
  clan.core.vars.generators.huggingface-read-token = {
    share = true;
    files.token.secret = true;
    prompts.token = {
      description = "Hugging Face read token for Leviathan model downloads";
      type = "hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''
      cat "$prompts"/token > "$out"/token
    '';
  };

  systemd.services.llm-weights-prepare = {
    description = "Prepare local GGUF model weights";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe prepareCommand} ${weightsManifest}";
      LoadCredential = [ "hf-token:${hfTokenPath}" ];
      TimeoutStartSec = "infinity";
      StateDirectory = "llm-weights";
      StateDirectoryMode = "0755";
      UMask = "0022";
      WorkingDirectory = stateDir;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ stateDir ];
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  systemd.timers.llm-weights-prepare = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnActiveSec = "15s";
      OnUnitActiveSec = "12h";
      Unit = "llm-weights-prepare.service";
    };
  };

  services.llama-swap = {
    enable = true;
    listenAddress = "0.0.0.0";
    inherit port;
    settings = {
      healthCheckTimeout = 900;
      includeAliasesInList = true;
      logToStdout = "proxy";
      models = lib.mapAttrs mkModel localModels;
    };
  };

  systemd.services.llama-swap.environment = {
    CUDA_DEVICE_ORDER = "PCI_BUS_ID";
    CUDA_VISIBLE_DEVICES = "0,1";
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];

  environment.systemPackages = [
    llamaCpp
    pkgs.llama-swap
    prepareCommand
  ];
}

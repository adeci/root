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

  llamaCppChatTemplates = {
    # Keep reasoning parser and template from the same llama.cpp revision.
    # VibeThinker uses Qwen ChatML and emits <think> tags, but its GGUF
    # template does not advertise thinking markers. QwQ's template does.
    qwen-qwq-thinking = "${llamaCpp.src}/models/templates/Qwen-QwQ-32B.jinja";
  };

  resolveChatTemplate =
    name: llamaCppChatTemplates.${name} or (throw "unknown LLM chat template: ${name}");

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

  runtimeProfiles = {
    single-v100-gpu0 = {
      env = [ "CUDA_VISIBLE_DEVICES=0" ];
      splitMode = "none";
      tensorSplit = null;
      extraArgs = [
        "--main-gpu"
        "0"
      ];
    };

    single-v100-gpu1 = {
      env = [ "CUDA_VISIBLE_DEVICES=1" ];
      splitMode = "none";
      tensorSplit = null;
      extraArgs = [
        "--main-gpu"
        "0"
      ];
    };

    dual-v100-split = {
      env = [ "CUDA_VISIBLE_DEVICES=0,1" ];
      splitMode = "layer";
      tensorSplit = "1,1";
    };
  };

  runtimeGroups = {
    # Small models in this group may stay loaded together.
    swarm = {
      swap = false;
      exclusive = true;
    };

    # Large models use the whole box and swap each other on demand.
    exclusive = {
      swap = true;
      exclusive = true;
    };
  };

  groupFor = model: model.runtime.group or "exclusive";
  membersForGroup =
    group: lib.filter (name: groupFor localModels.${name} == group) (builtins.attrNames localModels);

  llamaSwapGroups = lib.filterAttrs (_: group: group.members != [ ]) (
    lib.mapAttrs (name: settings: settings // { members = membersForGroup name; }) runtimeGroups
  );

  mkModel =
    _name: model:
    let
      weight = weights.${model.backend.weight};
      runtime = model.runtime or { };
      profileName = runtime.profile or "dual-v100-split";
      profile = runtimeProfiles.${profileName} or (throw "unknown LLM runtime profile: ${profileName}");
      perSlotContext = model.contextWindow or weight.nativeContextWindow;
      slots = runtime.slots or profile.slots or 1;
      totalContext = perSlotContext * slots;
      modelPath = "${stateDir}/models/${model.backend.weight}/${weight.entrypoint}";
      splitMode = profile.splitMode or null;
      tensorSplit = profile.tensorSplit or null;
      chatTemplateFile =
        if runtime ? chatTemplate then
          resolveChatTemplate runtime.chatTemplate
        else
          runtime.chatTemplateFile or null;
      useJinja = runtime.useJinja or (chatTemplateFile != null);
      reasoningFormat = runtime.reasoningFormat or null;
      extraArgs = (profile.extraArgs or [ ]) ++ (runtime.extraArgs or [ ]);
      serverArgs = lib.escapeShellArgs (
        [
          "--host"
          "127.0.0.1"
          "-m"
          modelPath
          "-ngl"
          "999"
        ]
        ++ lib.optionals useJinja [
          "--jinja"
        ]
        ++ lib.optionals (chatTemplateFile != null) [
          "--chat-template-file"
          chatTemplateFile
        ]
        ++ lib.optionals (splitMode != null) [
          "--split-mode"
          splitMode
        ]
        ++ lib.optionals (tensorSplit != null) [
          "--tensor-split"
          tensorSplit
        ]
        ++ lib.optionals (reasoningFormat != null) [
          "--reasoning-format"
          reasoningFormat
        ]
        ++ [
          "-c"
          (toString totalContext)
          "-np"
          (toString slots)
          "--no-webui"
        ]
        ++ extraArgs
      );
    in
    {
      ttl = model.ttl or 3600;
      env = [ "CUDA_DEVICE_ORDER=PCI_BUS_ID" ] ++ (profile.env or [ ]) ++ (runtime.env or [ ]);
      concurrencyLimit = slots;
      cmd = ''
        ${llamaServer} ${serverArgs} --port ''${PORT}
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
      healthCheckTimeout = 1800;
      includeAliasesInList = true;
      logToStdout = "proxy";
      models = lib.mapAttrs mkModel localModels;
      groups = llamaSwapGroups;
    };
  };

  systemd.services.llama-swap.environment.CUDA_DEVICE_ORDER = "PCI_BUS_ID";

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];

  environment.systemPackages = [
    llamaCpp
    pkgs.llama-swap
    prepareCommand
  ];
}

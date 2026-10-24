let
  weights = import ./weights.nix;

  mkLocal =
    model:
    let
      weight = weights.${model.backend.weight};
    in
    model
    // {
      contextWindow = model.contextWindow or weight.nativeContextWindow;
      maxTokens = model.maxTokens or weight.nativeMaxOutputTokens or weight.nativeContextWindow;
    };

  # VibeThinker emits <think> blocks but ships plain Qwen ChatML metadata.
  # Use llama.cpp's QwQ ChatML template so reasoning streams as reasoning_content.
  vibeThinkerRuntime = {
    group = "swarm";
    slots = 4;
    chatTemplate = "qwen-qwq-thinking";
    reasoningFormat = "deepseek";
  };
in
{
  vibethinker-3b-bf16-gpu0 = mkLocal {
    displayName = "VibeThinker 3B BF16 GPU 0";
    backend = {
      type = "local-gguf";
      weight = "vibethinker-3b-bf16";
    };
    mode = "chat";
    runtime = vibeThinkerRuntime // {
      profile = "single-v100-gpu0";
    };
  };

  vibethinker-3b-bf16-gpu1 = mkLocal {
    displayName = "VibeThinker 3B BF16 GPU 1";
    backend = {
      type = "local-gguf";
      weight = "vibethinker-3b-bf16";
    };
    mode = "chat";
    runtime = vibeThinkerRuntime // {
      profile = "single-v100-gpu1";
    };
  };

  qwen3-6-27b-q8 = mkLocal {
    displayName = "Qwen3.6 27B Q8";
    backend = {
      type = "local-gguf";
      weight = "qwen3-6-27b-q8";
    };
    mode = "chat";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };

  qwen3-6-35b-a3b-q8 = mkLocal {
    displayName = "Qwen3.6 35B A3B Q8";
    backend = {
      type = "local-gguf";
      weight = "qwen3-6-35b-a3b-q8";
    };
    mode = "chat";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };

  qwen3-coder-next-q4 = mkLocal {
    displayName = "Qwen3 Coder Next Q4";
    backend = {
      type = "local-gguf";
      weight = "qwen3-coder-next-q4";
    };
    mode = "chat";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };

  qwen3-coder-next-q5 = mkLocal {
    displayName = "Qwen3 Coder Next Q5";
    backend = {
      type = "local-gguf";
      weight = "qwen3-coder-next-q5";
    };
    mode = "chat";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };
}

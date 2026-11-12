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
    };

  # VibeThinker emits <think> blocks but ships plain Qwen ChatML metadata; llama.cpp's QwQ ChatML template streams them as reasoning_content.
  vibeThinkerRuntime = {
    group = "swarm";
    slots = 4;
    chatTemplate = "qwen-qwq-thinking";
    reasoningFormat = "deepseek";
  };
in
{
  vibethinker-3b-bf16-gpu0 = mkLocal {
    backend.weight = "vibethinker-3b-bf16";
    runtime = vibeThinkerRuntime // {
      profile = "single-v100-gpu0";
    };
  };

  vibethinker-3b-bf16-gpu1 = mkLocal {
    backend.weight = "vibethinker-3b-bf16";
    runtime = vibeThinkerRuntime // {
      profile = "single-v100-gpu1";
    };
  };

  qwen3-6-27b-q8 = mkLocal {
    backend.weight = "qwen3-6-27b-q8";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };

  qwen3-6-35b-a3b-q8 = mkLocal {
    backend.weight = "qwen3-6-35b-a3b-q8";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };

  qwen3-coder-next-q4 = mkLocal {
    backend.weight = "qwen3-coder-next-q4";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };

  qwen3-coder-next-q5 = mkLocal {
    backend.weight = "qwen3-coder-next-q5";
    runtime = {
      profile = "dual-v100-split";
      group = "exclusive";
    };
  };
}

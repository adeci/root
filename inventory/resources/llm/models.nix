{
  "gpt-5.5" = {
    displayName = "GPT-5.5";
    backend = {
      type = "litellm";
      model = "chatgpt/gpt-5.5";
    };
    mode = "responses";
    pricing = {
      source = "litellm";
      model = "gpt-5.5";
      fields = [
        "max_input_tokens"
        "max_output_tokens"
        "max_tokens"
        "input_cost_per_token"
        "input_cost_per_token_above_272k_tokens"
        "output_cost_per_token"
        "output_cost_per_token_above_272k_tokens"
        "cache_read_input_token_cost"
        "cache_read_input_token_cost_above_272k_tokens"
      ];
    };
  };

  nex-n2-mini-q6 = {
    displayName = "Nex N2 Mini Q6";
    backend = {
      type = "local-gguf";
      weight = "nex-n2-mini-q6";
    };
    mode = "chat";
    contextWindow = 32768;
    maxTokens = 4096;
  };

  north-mini-code-q6 = {
    displayName = "North Mini Code Q6";
    backend = {
      type = "local-gguf";
      weight = "north-mini-code-q6";
    };
    mode = "chat";
    contextWindow = 32768;
    maxTokens = 4096;
  };

  qwen3-6-27b-q8 = {
    displayName = "Qwen3.6 27B Q8";
    backend = {
      type = "local-gguf";
      weight = "qwen3-6-27b-q8";
    };
    mode = "chat";
    contextWindow = 32768;
    maxTokens = 4096;
  };

  qwen3-6-35b-a3b-q8 = {
    displayName = "Qwen3.6 35B A3B Q8";
    backend = {
      type = "local-gguf";
      weight = "qwen3-6-35b-a3b-q8";
    };
    mode = "chat";
    contextWindow = 32768;
    maxTokens = 4096;
  };

  qwen3-coder-next-q4 = {
    displayName = "Qwen3 Coder Next Q4";
    backend = {
      type = "local-gguf";
      weight = "qwen3-coder-next-q4";
    };
    mode = "chat";
    contextWindow = 32768;
    maxTokens = 4096;
  };

  qwen3-coder-next-q5 = {
    displayName = "Qwen3 Coder Next Q5";
    backend = {
      type = "local-gguf";
      weight = "qwen3-coder-next-q5";
    };
    mode = "chat";
    contextWindow = 65536;
    maxTokens = 4096;
  };
}

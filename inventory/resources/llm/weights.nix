{
  vibethinker-3b-bf16 = {
    displayName = "VibeThinker 3B BF16";
    family = "vibethinker";
    quant = "BF16";
    format = "gguf";
    tags = [
      "chat"
      "reasoning"
      "math"
      "coding"
      "lossless"
    ];
    source = {
      provider = "huggingface";
      repo = "prithivMLmods/VibeThinker-3B-GGUF";
      revision = "c94abbc502a2fb1aa54afc5048dafaeb84a7ba4e";
      files."VibeThinker-3B.BF16.gguf" = {
        sha256 = "79805a9e6f748890d82f3865165a31b60584149785ac01d3ae84bffc840e829f";
        size = 6178316992;
      };
    };
    entrypoint = "VibeThinker-3B.BF16.gguf";
    nativeContextWindow = 131072;
    nativeMaxOutputTokens = 65536;
    sizeGiB = 5.8;
  };

  qwen3-6-27b-q8 = {
    displayName = "Qwen3.6 27B Q8";
    family = "qwen3.6";
    quant = "Q8_0";
    format = "gguf";
    tags = [
      "chat"
      "coding"
      "dense"
    ];
    source = {
      provider = "huggingface";
      repo = "unsloth/Qwen3.6-27B-GGUF";
      revision = "82d411acf4a06cfb8d9b073a5211bf410bfc29bf";
      files."Qwen3.6-27B-Q8_0.gguf" = {
        sha256 = "f93f517f38e696d35a1a7df2c0e3155a64f4c4dcd662107a146ae263f7fb14ce";
        size = 28595763424;
      };
    };
    entrypoint = "Qwen3.6-27B-Q8_0.gguf";
    nativeContextWindow = 262144;
    nativeMaxOutputTokens = 81920;
    sizeGiB = 26.6;
  };

  qwen3-6-35b-a3b-q8 = {
    displayName = "Qwen3.6 35B A3B Q8";
    family = "qwen3.6";
    quant = "Q8_0";
    format = "gguf";
    tags = [
      "chat"
      "coding"
      "moe"
    ];
    source = {
      provider = "huggingface";
      repo = "unsloth/Qwen3.6-35B-A3B-GGUF";
      revision = "a483e9e6cbd595906af30beda3187c2663a1118c";
      files."Qwen3.6-35B-A3B-Q8_0.gguf" = {
        sha256 = "d1a395809f65a43a13ad119eb4e7acdef1ac6d68120f39902c8ab96e72794a59";
        size = 36903140320;
      };
    };
    entrypoint = "Qwen3.6-35B-A3B-Q8_0.gguf";
    nativeContextWindow = 262144;
    nativeMaxOutputTokens = 81920;
    sizeGiB = 34.4;
  };

  qwen3-coder-next-q4 = {
    displayName = "Qwen3 Coder Next Q4_K_M";
    family = "qwen3-coder-next";
    quant = "Q4_K_M";
    format = "gguf";
    tags = [
      "chat"
      "coding"
      "agentic"
    ];
    source = {
      provider = "huggingface";
      repo = "Qwen/Qwen3-Coder-Next-GGUF";
      revision = "b82fb7382639d97b38fa7672e526c760c2fb358e";
      files = {
        "Qwen3-Coder-Next-Q4_K_M/Qwen3-Coder-Next-Q4_K_M-00001-of-00004.gguf" = {
          sha256 = "6bcfc9f9c37901eeb92172e2ab871224dab36a453d263bcb2547f737409534da";
          size = 15524827040;
        };
        "Qwen3-Coder-Next-Q4_K_M/Qwen3-Coder-Next-Q4_K_M-00002-of-00004.gguf" = {
          sha256 = "817def0691ee9d08bf3dc4444be7aed29c9e52091e8fa9d97901ce7e7f6f01d3";
          size = 14872168352;
        };
        "Qwen3-Coder-Next-Q4_K_M/Qwen3-Coder-Next-Q4_K_M-00003-of-00004.gguf" = {
          sha256 = "23aa634d47dca9b4ca3ea249384e6f01951b24c83cdc076f37f6f43d6c99883f";
          size = 14503294496;
        };
        "Qwen3-Coder-Next-Q4_K_M/Qwen3-Coder-Next-Q4_K_M-00004-of-00004.gguf" = {
          sha256 = "249c768cc5f130dc731567d6edcbdacc48e14dec9e02c5dbe2b2185d2c5bdb2b";
          size = 3510702144;
        };
      };
    };
    entrypoint = "Qwen3-Coder-Next-Q4_K_M/Qwen3-Coder-Next-Q4_K_M-00001-of-00004.gguf";
    nativeContextWindow = 262144;
    nativeMaxOutputTokens = 65536;
    sizeGiB = 45.1;
  };

  qwen3-coder-next-q5 = {
    displayName = "Qwen3 Coder Next Q5_K_M";
    family = "qwen3-coder-next";
    quant = "Q5_K_M";
    format = "gguf";
    tags = [
      "chat"
      "coding"
      "agentic"
    ];
    source = {
      provider = "huggingface";
      repo = "Qwen/Qwen3-Coder-Next-GGUF";
      revision = "b82fb7382639d97b38fa7672e526c760c2fb358e";
      files = {
        "Qwen3-Coder-Next-Q5_K_M/Qwen3-Coder-Next-Q5_K_M-00001-of-00004.gguf" = {
          sha256 = "d68162877891c4ba309c8601a69721ecfc7be2091ad99e8175a078ae59decdd3";
          size = 17813589920;
        };
        "Qwen3-Coder-Next-Q5_K_M/Qwen3-Coder-Next-Q5_K_M-00002-of-00004.gguf" = {
          sha256 = "3da1a3fda1061009126eb48c7098221653ab63e0a266d3b6d04f5eac3ae9aa74";
          size = 17479501728;
        };
        "Qwen3-Coder-Next-Q5_K_M/Qwen3-Coder-Next-Q5_K_M-00003-of-00004.gguf" = {
          sha256 = "df60c7a55c6e118d4984a829b74df6b9e863dcea749ee7dc25ab5e72913624e1";
          size = 17226413600;
        };
        "Qwen3-Coder-Next-Q5_K_M/Qwen3-Coder-Next-Q5_K_M-00004-of-00004.gguf" = {
          sha256 = "777ac63a6f94272934996b1cfd7e5619c6804e8580ec4e00311d2a465e298c6a";
          size = 4190867520;
        };
      };
    };
    entrypoint = "Qwen3-Coder-Next-Q5_K_M/Qwen3-Coder-Next-Q5_K_M-00001-of-00004.gguf";
    nativeContextWindow = 262144;
    nativeMaxOutputTokens = 65536;
    sizeGiB = 52.8;
  };
}

{
  diffusiongemma-26b-a4b-it-q6 = {
    displayName = "DiffusionGemma 26B A4B Instruct Q6_K";
    family = "diffusiongemma";
    quant = "Q6_K";
    format = "gguf";
    tags = [
      "chat"
      "experimental"
      "multimodal"
    ];
    source = {
      provider = "huggingface";
      repo = "unsloth/diffusiongemma-26B-A4B-it-GGUF";
      revision = "aab0a2972da0e41310fbcca5ea63fc47eb932a71";
      files."diffusiongemma-26B-A4B-it-Q6_K.gguf" = {
        sha256 = "2eb439010b5d63259795a4f516ceacf296a867477c168f7b25c65acabae57e3a";
        size = 22654490592;
      };
    };
    entrypoint = "diffusiongemma-26B-A4B-it-Q6_K.gguf";
    nativeContextWindow = 32768;
    sizeGiB = 21.1;
  };

  gemma4-12b-it-q8 = {
    displayName = "Gemma 4 12B Instruct Q8";
    family = "gemma4";
    quant = "Q8_0";
    format = "gguf";
    tags = [
      "chat"
      "fast"
      "multimodal"
    ];
    source = {
      provider = "huggingface";
      repo = "unsloth/gemma-4-12b-it-GGUF";
      revision = "3249fa54d5efa384afc552cc6700ad091efd5c39";
      files."gemma-4-12b-it-Q8_0.gguf" = {
        sha256 = "74d2d4f0b5b08ca8589d1a5f50e689c0984469f3cedbdc7d67458c6e9e35496a";
        size = 12669646240;
      };
    };
    entrypoint = "gemma-4-12b-it-Q8_0.gguf";
    nativeContextWindow = 32768;
    sizeGiB = 11.8;
  };

  nex-n2-mini-q6 = {
    displayName = "Nex N2 Mini Q6_K";
    family = "nex-n2";
    quant = "Q6_K";
    format = "gguf";
    tags = [
      "chat"
      "reasoning"
      "multimodal"
    ];
    source = {
      provider = "huggingface";
      repo = "bartowski/nex-agi_Nex-N2-mini-GGUF";
      revision = "dd97f3699eb8774503bb2d3661d54fc1c20d44d2";
      files."nex-agi_Nex-N2-mini-Q6_K.gguf" = {
        sha256 = "db5a19d15327471c1f2f04594c3da5bd978fa24fdd8c92aaa2df2c475f733b72";
        size = 30053414912;
      };
    };
    entrypoint = "nex-agi_Nex-N2-mini-Q6_K.gguf";
    nativeContextWindow = 32768;
    sizeGiB = 28.0;
  };

  north-mini-code-q6 = {
    displayName = "North Mini Code 1.0 Q6_K";
    family = "north-mini-code";
    quant = "Q6_K";
    format = "gguf";
    tags = [
      "chat"
      "coding"
    ];
    source = {
      provider = "huggingface";
      repo = "DevQuasar/CohereLabs.North-Mini-Code-1.0-GGUF";
      revision = "3194b7b515a37f57d9076290081819a9d163ffd4";
      files."CohereLabs.North-Mini-Code-1.0.Q6_K.gguf" = {
        sha256 = "330fee31be075e52f5bdb6f51236d2fec2e076922cb6d6833a872d9411097a44";
        size = 25057444672;
      };
    };
    entrypoint = "CohereLabs.North-Mini-Code-1.0.Q6_K.gguf";
    nativeContextWindow = 32768;
    sizeGiB = 23.3;
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
    nativeContextWindow = 32768;
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
    nativeContextWindow = 32768;
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
    nativeContextWindow = 32768;
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
    nativeContextWindow = 32768;
    sizeGiB = 52.8;
  };
}

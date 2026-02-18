{
  config,
  lib,
  ...
}:
let
  cfg = config.adeci.numtide-cache;
in
{
  options.adeci.numtide-cache.enable = lib.mkEnableOption "Numtide binary cache (llm-agents packages)";
  config = lib.mkIf cfg.enable {
    nix.settings = {
      extra-substituters = [ "https://cache.numtide.com" ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
  };
}

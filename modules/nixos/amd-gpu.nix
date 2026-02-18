{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.adeci.amd-gpu;
in
{
  options.adeci.amd-gpu.enable = lib.mkEnableOption "AMD GPU monitoring support";
  config = lib.mkIf cfg.enable {
    # btop needs rocm-smi and libdrm in ld path for gpu monitoring
    environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.rocmPackages.rocm-smi}/lib:${pkgs.libdrm}/lib";
  };
}

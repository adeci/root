{ pkgs, ... }:
{
  hardware.amdgpu.opencl.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # btop needs rocm-smi and libdrm in ld path for gpu monitoring
  environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.rocmPackages.rocm-smi}/lib:${pkgs.libdrm}/lib";
}

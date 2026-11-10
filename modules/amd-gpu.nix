{
  nixos =
    { self, ... }:
    {
      imports = [ self.modules.nixos.wrappers ];

      hardware.amdgpu.opencl.enable = true;
      services.xserver.videoDrivers = [ "amdgpu" ];
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
      wrappers.btop.amdGpu = true;
    };
}

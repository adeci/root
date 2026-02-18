{
  inputs,
  pkgs,
  config,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  networking = {
    hostName = "aegis";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  imports = [

    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220

    ../../modules/nixos
  ];

  adeci = {
    base.enable = true;
    dev.enable = true;
    shell.enable = true;
    niri.enable = true;
    keyd.enable = true;
    laptop.enable = true;
  };

  environment.systemPackages = with pkgs; [
    firefox
  ];

  # Grant CAP_PERFMON to btop so it can monitor Intel GPU without root
  security.wrappers.btop = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon+ep";
    source = "${packages.btop}/bin/btop";
  };

  # Enable Intel graphics acceleration for Sandy Bridge
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-vaapi-driver # i965 driver - only VA-API driver that supports Sandy Bridge
    ];
  };

  # Explicitly set VA-API driver to i965 for Sandy Bridge
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };

  nix.settings.trusted-users = [
    "root"
    config.adeci.primaryUser
  ];

}

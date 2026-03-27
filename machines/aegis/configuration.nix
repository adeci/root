{
  inputs,
  pkgs,
  self,
  ...
}:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220

    self.users.alex.nixosModule

    ../../modules/nixos/home-manager.nix

    ../../modules/nixos/base.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/dev.nix
    ../../modules/nixos/niri.nix
    ../../modules/nixos/niri-autologin.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/social.nix
    ../../modules/nixos/yubikey.nix
    ../../modules/nixos/mullvad.nix
  ];

  home-manager.users.alex = import ./home.nix;

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
    self.users.alex.username
  ];

}

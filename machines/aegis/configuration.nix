{ inputs, pkgs, ... }:

let
  dotpkgs = inputs.adeci-dotpkgs.packages.${pkgs.stdenv.hostPlatform.system};
  wrappers = inputs.adeci-wrappers;
  modus-waybar = (import ../modus/modules/waybar/module.nix { inherit pkgs wrappers; }).waybar;
  modus-swayosd = (import ../modus/modules/swayosd/module.nix { inherit pkgs wrappers; }).swayosd;
in
{
  networking = {
    hostName = "aegis";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  imports = [

    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220

    ../../modules/adeci/all.nix
    ../../modules/adeci/dev.nix
    ../../modules/adeci/shell.nix

    ../../modules/adeci/niri.nix
    ../../modules/adeci/laptop.nix
  ];

  environment.systemPackages =
    with pkgs;
    [
      firefox
    ]
    ++ [
      modus-waybar
      modus-swayosd
    ];

  # Grant CAP_PERFMON to btop so it can monitor Intel GPU without root
  security.wrappers.btop = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon+ep";
    source = "${dotpkgs.btop}/bin/btop";
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

  services = {

    # Keyd for dual-function keys (Caps Lock = Esc on tap, Ctrl on hold)
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
            };
          };
        };
      };
    };

  };

  nix.settings = {
    http-connections = 64;
    max-substitution-jobs = 64;
    download-buffer-size = 268435456; # 256MB

    trusted-users = [
      "root"
      "alex"
    ];
  };

}

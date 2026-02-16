{
  inputs,
  pkgs,
  config,
  ...
}:

let
  dotpkgs = import ../../dotpkgs { inherit pkgs inputs; };
in
{
  networking = {
    hostName = "aegis";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  imports = [

    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220

    ../../nix-modules/all.nix
    ../../nix-modules/dev.nix
    ../../nix-modules/shell.nix

    ../../nix-modules/niri.nix
    ../../nix-modules/laptop.nix
    ../../nix-modules/home-manager.nix
  ];

  environment.systemPackages = with pkgs; [
    firefox
  ];

  # Auto-login alex into niri via greetd
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.greetd}/bin/agreety --cmd niri-session";
      user = "alex";
    };
    settings.initial_session = {
      command = "niri-session";
      user = "alex";
    };
  };
  security.pam.services.greetd.enableGnomeKeyring = true;

  # Grant CAP_PERFMON to btop so it can monitor Intel GPU without root
  security.wrappers.btop = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon+ep";
    source = "${dotpkgs.btop.wrapper}/bin/btop";
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

  home-manager.users.alex = {
    imports = [ ./home.nix ];
    home.stateVersion = config.system.stateVersion;
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

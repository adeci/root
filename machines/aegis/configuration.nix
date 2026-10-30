{
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;

  # security.wrappers needs an ELF; the configured btop script execs this.
  btopPerfmon = pkgs.runCommandLocal "btop-perfmon" { meta.mainProgram = "btop"; } ''
    mkdir -p $out/bin
    ln -s /run/wrappers/bin/btop-perfmon $out/bin/btop
  '';
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220

    self.users.alex.nixosModule

    ../../modules/nixos/base.nix
    ../../modules/nixos/nvim-dev.nix
    ../../modules/nixos/zsh.nix
    ../../modules/nixos/atuin-login.nix
    ../../modules/nixos/llm-tools.nix
    ../../modules/nixos/auto-pressure-gc.nix
    ../../modules/nixos/auto-timezone.nix
    ../../modules/nixos/smartd.nix
    ../../modules/nixos/desktop
    ../../modules/nixos/niri
    ../../modules/nixos/noctalia.nix
    ../../modules/nixos/niri/autologin.nix
    ../../modules/nixos/keyd.nix
    ../../modules/nixos/zram.nix
    ../../modules/nixos/laptop.nix
    ../../modules/nixos/printing.nix
    ../../modules/nixos/social.nix
    ../../modules/nixos/yubikey.nix
    ../../modules/nixos/mullvad.nix
    ../../modules/nixos/rbw.nix
    ../../modules/nixos/cheat.nix
  ];

  thaw.apps.niri.files."machine.kdl" = ./niri.kdl;

  environment.systemPackages = [
    # pkgs.bitwarden-desktop # Electron 39 is EOL; re-enable once nixpkgs updates it
    pkgs.mullvad-browser
    pkgs.openscad
    (lib.hiPrio (self.packages.${system}.btop.wrap { package = btopPerfmon; }))
  ];

  # tp_smapi lacks .ko.cer files; drop once NixOS/nixpkgs#578004 lands.
  boot.kernelPackages = pkgs.linuxPackages.extend (
    kfinal: kprev: {
      tp_smapi = kprev.tp_smapi.overrideAttrs {
        installPhase = ''
          runHook preInstall
          mv hdaps.ko hdapsd.ko
          sed -i 's/^hdaps\.o$/hdapsd.o/' modules.order
          make -C ${kfinal.kernel.dev}/lib/modules/${kfinal.kernel.modDirVersion}/build \
            M="$PWD" ${lib.escapeShellArgs kfinal.kernelModuleMakeFlags} \
            INSTALL_MOD_PATH="$out" INSTALL_MOD_DIR=kernel/drivers/firmware DEPMOD=true \
            modules_install
          runHook postInstall
        '';
      };
    }
  );

  # Sandy Bridge exposes GPU utilization through perf events rather than sysfs.
  # Grant only CAP_PERFMON to the two read-only monitoring tools that need it.
  security.wrappers = {
    btop-perfmon = {
      owner = "root";
      group = "root";
      capabilities = "cap_perfmon+ep";
      source = lib.getExe pkgs.btop;
    };
    intel_gpu_top = {
      owner = "root";
      group = "root";
      capabilities = "cap_perfmon+ep";
      source = "${pkgs.intel-gpu-tools}/bin/intel_gpu_top";
    };
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

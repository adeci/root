{
  inputs,
  lib,
  pkgs,
  self,
  ...
}:
let

  # security.wrappers needs an ELF; the configured btop script execs this.
  btopPerfmon = pkgs.runCommandLocal "btop-perfmon" { meta.mainProgram = "btop"; } ''
    mkdir -p $out/bin
    ln -s /run/wrappers/bin/btop-perfmon $out/bin/btop
  '';
in
{
  imports = with self.modules.nixos; [
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x220

    self.users.alex.nixosModule

    base
    nvim-dev
    zsh
    llm-tools
    auto-pressure-gc
    auto-timezone
    smartd
    desktop
    librewolf
    niri
    noctalia
    niri-autologin
    keyd
    zram
    laptop
    printing
    social
    yubikey
    mullvad
    rbw
    cheat
  ];

  wrappers.niri.machineConfig = # kdl
    ''
      output "LG Display 0x02D8 Unknown" {
          mode "1366x768@60.019"
          scale 1
      }

      input {
          trackpoint {
              accel-speed -0.25
              accel-profile "flat"
          }
      }
    '';

  environment.systemPackages = [
    # pkgs.bitwarden-desktop # Electron 39 is EOL; re-enable once nixpkgs updates it
    pkgs.openscad
  ];
  wrappers.btop.package = btopPerfmon;

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

  hardware.graphics.extraPackages = with pkgs; [
    intel-vaapi-driver # i965, the only VA-API driver that supports Sandy Bridge
  ];

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "i965";
  };
}

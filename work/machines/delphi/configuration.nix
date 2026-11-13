{
  pkgs,
  self,
  work,
  ...
}:
{
  imports = with self.modules.nixos; [
    work.inputs.nixos-hardware-xps14.nixosModules.dell-xps-14-da14260

    self.users.alex-work.nixosModule

    work.modules.nixos.apps
    work.modules.nixos.enrollment
    work.modules.nixos.shell
    work.modules.nixos.plain-git

    base
    nvim-dev
    kagi-search
    auto-timezone
    auto-pressure-gc
    btrfs
    smartd
    desktop
    librewolf
    plymouth
    keyring-tpm
    niri
    noctalia
    niri-autologin
    keyboard
    zram
    laptop
    printing
    yubikey
    ssh-tpm-agent
  ];

  wrappers.niri.machineConfig = # kdl
    ''
      input {
          // Replaces the shared touchpad section, which niri does not merge.
          touchpad {
              tap
              dwt
              natural-scroll
              // About 53% of libinput's default curve; tuned on this XPS 14.
              accel-speed -0.25
          }
      }
    '';

  nixpkgs.hostPlatform = "x86_64-linux";

  # Newest series confirmed on the DA14260.
  boot.kernelPackages = pkgs.linuxPackages_7_2;
}

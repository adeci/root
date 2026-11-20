{
  nixos =
    { pkgs, self, ... }:
    {
      environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.sdwire-cli ];

      # uaccess must sort before 73-seat-late.rules; extraRules is 99-local.rules.
      services.udev.packages = [
        (pkgs.writeTextDir "lib/udev/rules.d/70-sdwire.rules" ''
          # The USB device, and its block device for dd without sudo.
          SUBSYSTEM=="usb", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", TAG+="uaccess"
          SUBSYSTEM=="block", ATTRS{idVendor}=="0bda", ATTRS{idProduct}=="0316", TAG+="uaccess"

          # From sdwire-cli's own rules: without autosuspend the card does not switch to the target side.
          SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="0bda", ATTR{idProduct}=="0316", TEST=="power/control", ATTR{power/autosuspend_delay_ms}="0", ATTR{power/control}="auto"
        '')
      ];
    };
}

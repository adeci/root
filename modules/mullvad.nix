{
  nixos =
    { pkgs, ... }:
    {
      services.mullvad-vpn.enable = true;

      environment.systemPackages = [
        pkgs.mullvad
        pkgs.mullvad-compass
        pkgs.mullvad-browser
      ];
    };
}

{ pkgs, ... }:
{
  services.mullvad-vpn.enable = true;

  # mullvad CLI + compass (find optimal server)
  environment.systemPackages = with pkgs; [
    mullvad
    mullvad-compass
  ];
}

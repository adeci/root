{ self, ... }:
{
  # Unlike systemd-timesyncd, chrony also serves the time, here to the switches and access points.
  services.chrony = {
    enable = true;
    extraConfig = "allow ${self.inventory.lan.vlans.mgmt.cidr}";
  };
}

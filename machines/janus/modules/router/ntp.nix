{ self, ... }:
{
  # Unlike timesyncd, chrony also serves time, here to the switches and APs.
  services.chrony = {
    enable = true;
    extraConfig = "allow ${self.inventory.lan.vlans.mgmt.cidr}";
  };
}

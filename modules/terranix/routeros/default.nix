# RouterOS provider + shared resources
# Data layer consumed thru self.resources.routeros.<device>
# Switch-specific resources in switch.nix, WAP-specific in wap.nix.
{
  imports = [
    ./provider.nix
    ./switch.nix
    ./wap.nix
  ];
}

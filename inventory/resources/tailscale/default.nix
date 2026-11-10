let
  addresses = import ./addresses.nix;
in
{
  inherit addresses;
  # Tailscale's CGNAT range; every tailnet address falls inside it.
  cidr = "100.64.0.0/10";
  policy = import ./policy.nix { inherit addresses; };
  deviceTags = import ./device-tags.nix;
}

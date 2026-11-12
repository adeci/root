let
  machines = import ../../machines.nix;
  onTailnet = builtins.filter (name: machines.${name} ? tailnet) (builtins.attrNames machines);

  addresses = builtins.listToAttrs (
    map (name: {
      inherit name;
      value = machines.${name}.tailnet;
    }) onTailnet
  );
in
{
  # The tailnet's MagicDNS domain; each machine answers as <name>.<domain>.
  domain = "cymric-daggertooth.ts.net";
  inherit addresses;
  # Tailscale's CGNAT range; every tailnet address falls inside it.
  cidr = "100.64.0.0/10";
  policy = import ./policy.nix {
    inherit addresses;
    homelan = import ../homelan.nix;
  };
  # ACL tags set on tailnet devices through the Tailscale API, by hostname.
  deviceTags = {
    delphi = [ "tag:work" ];
    malum = [ "tag:work" ];
  };
}

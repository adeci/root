{ lib }:
let
  octets = address: map lib.toIntBase10 (lib.splitString "." address);

  powerOfTwo = n: if n == 0 then 1 else 2 * powerOfTwo (n - 1);

  # An IPv4 address as one number, so addresses compare and mask.
  addressNumber =
    address:
    let
      octet = lib.elemAt (octets address);
    in
    ((octet 0 * 256 + octet 1) * 256 + octet 2) * 256 + octet 3;
in
{
  inherit addressNumber;

  # Whether an address falls inside a block written as <address>/<prefix length>.
  inBlock =
    block: address:
    let
      parts = lib.splitString "/" block;
      size = powerOfTwo (32 - lib.toIntBase10 (lib.last parts));
    in
    builtins.div (addressNumber address) size == builtins.div (addressNumber (lib.head parts)) size;

  ipv4Address = lib.mkOptionType {
    name = "ipv4Address";
    description = "IPv4 address";
    check =
      address:
      builtins.isString address
      && builtins.match "([0-9]{1,3}\\.){3}[0-9]{1,3}" address != null
      && lib.all (octet: octet <= 255) (octets address);
    merge = lib.options.mergeEqualOption;
  };

  macAddress = lib.types.strMatching "([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}";

  # Where a cable leads, as { name, port }, port being null when it names none; null when malformed.
  parseCableEnd =
    end:
    let
      parts = builtins.match "([^:]+)(:([^:]+))?" end;
    in
    if parts == null then
      null
    else
      {
        name = lib.elemAt parts 0;
        port = lib.elemAt parts 2;
      };

  # What a port carries: the VLAN it sends untagged, if any, and the VLANs it tags, sorted.
  carriedVlans = untagged: tagged: {
    inherit untagged;
    tagged = lib.sort lib.lessThan (lib.unique tagged);
  };
}

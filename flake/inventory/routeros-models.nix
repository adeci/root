# MikroTik hardware by model: its RouterOS architecture, extra packages, ports and radios. schema.nix checks each appliance against it and publishes it as self.inventory.routeros.models.
let
  # A model's interface names: etherN, then sfp-sfpplusN.
  withPorts =
    model:
    model
    // {
      ports =
        builtins.genList (i: "ether${toString (i + 1)}") model.etherPorts
        ++ builtins.genList (i: "sfp-sfpplus${toString (i + 1)}") model.sfpPorts;
    };
in
builtins.mapAttrs (_: withPorts) {
  "CRS328-24P-4S+RM" = {
    arch = "arm";
    etherPorts = 24;
    sfpPorts = 4;
  };

  "CRS310-8G+2S+IN" = {
    arch = "arm";
    etherPorts = 8;
    sfpPorts = 2;
  };

  cAP-ax = {
    arch = "arm64";
    extraPackages = [ "wifi-qcom" ];
    etherPorts = 2;
    sfpPorts = 0;
    # wifi1 is 5GHz and wifi2 2.4GHz; these ids are stable after netinstall.
    radios = [
      {
        name = "wifi1";
        id = "*2";
      }
      {
        name = "wifi2";
        id = "*3";
      }
    ];
  };
}

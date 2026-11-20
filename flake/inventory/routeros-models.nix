# MikroTik hardware by model.
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
    # Same on every unit: wifi1 is 5GHz, wifi2 is 2.4GHz.
    radios = [
      "wifi1"
      "wifi2"
    ];
  };
}

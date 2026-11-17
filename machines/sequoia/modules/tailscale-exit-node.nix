{
  services.tailscale = {
    useRoutingFeatures = "server";

    extraUpFlags = [ "--advertise-exit-node" ];
    extraSetFlags = [ "--advertise-exit-node=true" ];
  };
}

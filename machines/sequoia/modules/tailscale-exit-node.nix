{
  services.tailscale = {
    useRoutingFeatures = "server";

    extraUpFlags = [ "--advertise-exit-node" ];
    extraSetFlags = [
      "--accept-routes=false"
      "--advertise-exit-node=true"
    ];
  };
}

{
  work-net = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer.tags = [ "work-net" ];
    # Work laptops run WARP, which owns DNS.
    roles.peer.settings.flags = [ "--accept-dns=false" ];
  };

  state-version = {
    module = {
      name = "importer";
      input = "clan-core";
    };
    roles.default.tags = [ "all" ];
    roles.default.settings.extraModules = [
      {
        clan.core.state-version.enable = true;
      }
    ];
  };
}

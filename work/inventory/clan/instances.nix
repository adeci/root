{
  work-net = {
    module = {
      name = "@adeci/tailscale";
      input = "self";
    };
    roles.peer.tags = [ "work-net" ];
    # Leave DNS to the local resolver
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

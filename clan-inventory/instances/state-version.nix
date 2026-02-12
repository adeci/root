{
  state-version = {
    module = {
      name = "importer";
      input = "clan-core";
    };
    roles.default.tags.all = { };
    roles.default.settings.extraModules = [
      {
        clan.core.state-version.enable = true;
      }
    ];
  };
}

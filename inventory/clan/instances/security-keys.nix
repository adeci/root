{
  security-keys = {
    module = {
      name = "@adeci/security-keys";
      input = "self";
    };
    roles.default = {
      settings.keys = [
        {
          name = "spark";
          owner = "alex";
        }
        {
          name = "ember";
          owner = "alex";
        }
      ];
      machines.aegis.settings.use = [
        "ember"
      ];
      machines.praxis.settings.use = [
        "spark"
      ];
    };
  };
}

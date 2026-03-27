{
  security-keys = {
    module = {
      name = "@adeci/security-keys";
      input = "self";
    };
    roles.default = {
      tags = [ "keybearers" ];
      settings.keys = [
        {
          name = "spark";
          owner = "alex";
        }
        # { name = "ember"; owner = "alex"; }  # TODO: generate on aegis security key
        # { name = "vault"; owner = "alex"; }  # TODO: generate on backup security key
      ];
    };
  };
}

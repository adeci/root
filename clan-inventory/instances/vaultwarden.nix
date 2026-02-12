{

  "sequoia-vault" = {
    module = {
      name = "@adeci/vaultwarden";
      input = "self";
    };
    roles.server = {
      machines.sequoia = {
        settings = {
          DOMAIN = "https://vault.decio.us";
        };
      };
    };
  };

}
